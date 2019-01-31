require 'yajl'
require 'docker'
require 'stringio'

require_relative 'exceptions'

class Hoosegow
  # Minimal API client for Docker, allowing attaching to container
  # stdin/stdout/stderr.
  class Docker
    ::Docker.options[:read_timeout]  = 3600
    ::Docker.options[:write_timeout] = 3600
    DEFAULT_HOST   = "127.0.0.1"
    DEFAULT_PORT   = 4243
    DEFAULT_SOCKET = "/var/run/docker.sock"

    # Initialize a new Docker API client.
    #
    # options - Connection options.
    #           :host   - IP or hostname to connect to (unless using Unix
    #                     socket).
    #           :port   - TCP port to connect to (unless using Unix socket).
    #           :socket - Path to local Unix socket (unless using host and
    #                     port).
    #           :after_create - A proc that will be called after a container is created.
    #           :after_start  - A proc that will be called after a container is started.
    #           :after_stop   - A proc that will be called after a container stops.
    #           :prestart - Start a new container after each `run_container` call.
    #           :volumes  - A mapping of volumes to mount in the container. e.g.
    #                       if the Dockerfile has `VOLUME /work`, where the container will
    #                       write data, and `VOLUME /config` where read-only configuration
    #                       is, you might use
    #                         :volumes => {
    #                           "/config" => "/etc/shared-config",
    #                           "/work"   => "/data/work:rw",
    #                         }
    #                       `:volumes => { "/work" => "/home/localuser/work/to/do" }`
    #           :Other - any option with a capitalized key will be passed on
    #                    to the 'create container' call. See http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.9/#create-a-container
    def initialize(options = {})
      set_docker_url! options
      @after_create      = options[:after_create]
      @after_start       = options[:after_start]
      @after_stop        = options[:after_stop]
      @volumes           = options[:volumes]
      @prestart          = options.fetch(:prestart, true)
      @container_options = options.select { |k,v| k =~ /\A[A-Z]/ }
    end

    # Public: Create and start a Docker container if one hasn't been started
    # already, then attach to it its stdin/stdout.
    #
    # image    - The image to run.
    # data     - The data to pipe to the container's stdin.
    #
    # Returns the data from the container's stdout.
    def run_container(image, data, &block)
      unless @prestart && @container
        create_container(image)
        start_container
      end

      begin
        attach_container(data, &block)
      ensure
        wait_container
        delete_container
        if @prestart
          create_container(image)
          start_container
        end
      end
      nil
    end

    # Public: Create a container using the specified image.
    #
    # image - The name of the image to start the container with.
    #
    # Returns nothing.
    def create_container(image)
      @container = ::Docker::Container.create @container_options.merge(
        :StdinOnce  => true,
        :OpenStdin  => true,
        :HostConfig => {
          :Binds    => volumes_for_bind
        },
        :Image     => image
      )
      callback @after_create
    end

    # Public: Start a Docker container.
    #
    # Returns nothing.
    def start_container
      @container.start
      callback @after_start
    end

    # Attach to a container, writing data to container's STDIN.
    #
    # Returns combined STDOUT/STDERR from container.
    def attach_container(data, &block)
      stdin = StringIO.new data
      @container.attach :stdin => stdin, &block
    end

    # Public: Wait for a container to finish.
    #
    # Returns nothing.
    def wait_container
      @container.wait
      callback @after_stop
    end

    # Public: Stop the running container.
    #
    # Returns response body or nil if no container is running.
    def stop_container
      return unless @container
      @container.stop :timeout => 0
      callback @after_stop
    end

    # Public: Delete the last started container.
    #
    # Returns response body or nil if no container was started.
    def delete_container
      return unless @container
      @container.delete :v => 1
    rescue ::Docker::Error::ServerError => e
      $stderr.puts "Docker could not delete #{@container.id}: #{e}"
    end

    # Public: Build a new image.
    #
    # name    - The name to give the image.
    # tarfile - Tarred data for creating image. See http://docs.docker.io/en/latest/api/docker_remote_api_v1.5/#build-an-image-from-dockerfile-via-stdin
    #
    # Returns Array of build result objects from the Docker API.
    def build_image(name, tarfile, build_opts = {})
      # Setup parser to receive chunks and yield parsed JSON objects.
      ret = []
      error = nil
      parser = Yajl::Parser.new
      parser.on_parse_complete = Proc.new do |obj|
        ret << obj
        error = Hoosegow::ImageBuildError.new(obj) if obj["error"]
        yield obj if block_given?
      end

      # Make API call to create image.
      opts = {:t => name, :rm => '1'}.merge(build_opts)
      ::Docker::Image.build_from_tar StringIO.new(tarfile), opts do |chunk|
        parser << chunk
      end

      raise error if error

      # Return Array of received objects.
      ret
    end

    # Check if a Docker image exists.
    #
    # name - The name of the image to check for.
    #
    # Returns true/false.
    def image_exist?(name)
      ::Docker::Image.exist? name
    end

  private
    # Private: Set the docker URL, if related options are present.
    def set_docker_url!(options)
      if url = docker_url(options)
        ::Docker.url = url
      end
    end

    # Private: Get the URL to use for communicating with Docker. If a host and/or
    # port a present, a TCP socket URL will be generated. Otherwise a Unix
    # socket will be used.
    #
    # options - A Hash of options for building the URL.
    #           :host   - The hostname or IP of a remote Docker daemon
    #                     (optional).
    #           :port   - The TCP port of the remote Docker daemon (optional).
    #           :socket - The path of a local Unix socket (optional).
    #
    # Returns a String url.
    def docker_url(options)
      if options[:host] || options[:port]
        host = options[:host] || DEFAULT_HOST
        port = options[:port] || DEFAULT_PORT
        "tcp://#{host}:#{port}"
      elsif path = options[:socket]
        "unix://#{path}"
      else
        nil
      end
    end

    # Private: Generate the `Binds` argument for creating a container.
    #
    # Given a hash of container_path => local_path in @volumes, generate an
    # array of "local_path:container_path:rw".
    def volumes_for_bind
      result = []
      each_volume do |container_path, local_path, permissions|
        result << "#{local_path}:#{container_path}:#{permissions}"
      end
      result
    end

    # Private: Yields information about each `@volume`.
    #
    #   each_volume do |container_path, local_path, permissions|
    #   end
    def each_volume
      if @volumes
        @volumes.each do |container_path, local_path|
          local_path, permissions = local_path.split(':', 2)
          permissions ||= "ro"
          yield container_path, local_path, permissions
        end
      end
    end

    def callback(callback_proc)
      callback_proc.call(@container.info) if callback_proc
    rescue Object
    end
  end
end
