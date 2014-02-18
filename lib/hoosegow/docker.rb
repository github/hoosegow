require 'net/http'
require 'socket'
require 'json'
require 'uri'

require_relative 'exceptions'

class Hoosegow
  # Minimal API client for Docker, allowing attaching to container
  # stdin/stdout/stderr.
  class Docker
    HEADERS = {"Content-Type" => "application/json"}

    # Initialize a new Docker API client.
    #
    # options - Connection options.
    #           :host   - IP or hostname to connect to (unless using Unix
    #                     socket).
    #           :port   - TCP port to connect to (unless using Unix socket).
    #           :socket - Path to local Unix socket (unless using host and
    #                     port).
    #           :prestart - Start a new container after each `run_container` call.
    def initialize(options = {})
      if options[:host] || options[:port]
        @host   = options[:host] || "127.0.0.1"
        @port   = options[:port] || 4243
      else
        @socket_path = options[:socket] || "/var/run/docker.sock"
      end
      @prestart = options.fetch(:prestart, true)
    end

    # Public: Create and start a Docker container if one hasn't been started
    # already, then attach to it its stdin/stdout.
    #
    # image    - The image to run.
    # data     - The data to pipe to the container's stdin.
    #
    # Returns the data from the container's stdout.
    def run_container(image, data)
      start_container(image) unless @prestart && @id
      res = attach_container data
      wait_container
      delete_container
      start_container(image) if @prestart
      res
    end

    # Public: Create and start a Docker container.
    #
    # image_name - The name of the image to start the container with.
    #
    # Returns nothing.
    def start_container(image)
      # Create container.
      create_body = JSON.dump :StdinOnce => true, :OpenStdin => true, :image => image
      res         = post uri(:create), create_body
      @id         = JSON.load(res)["Id"]

      # Start container
      post uri(:start, @id)
    end

    # Attach to a container, writing data to container's STDIN.
    #
    # Returns combined STDOUT/STDERR from container.
    def attach_container(data)
      params  = {:stdout => 1, :stderr => 1, :stdin => 1, :logs => 0, :stream => 1}
      request = Net::HTTP::Post.new uri(:attach, @id, params), HEADERS
      res     = transport_request request, data
      demux_streams res
    end

    # Public: Wait for a container to finish.
    #
    # Returns nothing.
    def wait_container
      post uri(:wait, @id)
    end

    # Public: Stop the running container.
    #
    # Returns response body or nil if no container is running.
    def stop_container
      return unless @id
      post uri(:stop, @id, :t => 0)
    end

    # Public: Delete the last started container.
    #
    # Returns response body or nil if no container was started.
    def delete_container
      return unless @id
      delete = Net::HTTP::Delete.new uri(:delete, @id), HEADERS
      transport_request delete
    end

    # Public: Build a new image.
    #
    # name    - The name to give the image.
    # tarfile - Tarred data for creating image. See http://docs.docker.io/en/latest/api/docker_remote_api_v1.5/#build-an-image-from-dockerfile-via-stdin
    #
    # Returns build results.
    def build_image(name, tarfile)
      post uri(:build, :t => name), tarfile do |json|
        data = JSON.load(json)
        raise Hoosegow::ImageBuildError.new(data) if data['error']
        yield data if block_given?
      end
    end

    # Get information about an image.
    #
    # name - The name of the image to get info about.
    #
    # Returns raw response string.
    def inspect_image(name)
      get uri(:inspect, name)
    end

  private

    # Private: Send a GET request to the API.
    #
    # uri - API URI to GET to.
    #
    # Returns the response body.
    def get(uri)
      request = Net::HTTP::Get.new uri
      transport_request request
    end

    # Private: Send a POST request to the API.
    #
    # uri    - API URI to POST to.
    # data   - Data for POST body.
    #
    # Returns the response body.
    def post(uri, data = '{}', &block)
      request = Net::HTTP::Post.new uri, HEADERS
      request.body = data
      transport_request request, &block
    end

    # Private: Connects to API host or local socket, transmits the request, and
    # reads in the response.
    #
    # request - A Net::HTTPResponse object without a body set.
    #
    # Returns the response body.
    def transport_request(request, data = nil)
      request = request
      socket  = new_socket
      request.exec socket, "1.1", request.path

      begin
        response = Net::HTTPResponse.read_new(socket)
      end while response.kind_of?(Net::HTTPContinue)

      socket.write(data) if data
      response.reading_body(socket, request.response_body_permitted?) do
        if block_given?
          response.read_body do |segment|
            yield segment
          end
        end
      end
      response.body
    end

    # Private: Create a connection to API host or local Unix socket.
    #
    # Returns Net::BufferedIO socket object.
    def new_socket
      socket = if @socket_path
                 UNIXSocket.new(@socket_path)
               else
                 TCPSocket.open @host, @port
               end
      socket = Net::BufferedIO.new socket
      socket.read_timeout = nil
      socket
    end

    API_PATHS = {
      :create  => "/containers/create",
      :attach  => "/containers/%s/attach",
      :start   => "/containers/%s/start",
      :stop    => "/containers/%s/stop",
      :wait    => "/containers/%s/wait",
      :delete  => "/containers/%s",
      :build   => "/build",
      :inspect => "/images/%s/json"
    }

    # Private: Build a URI for a given API endpount, encorporating any
    # arguments or parameters.
    #
    # endpoint - The Symbol name for an API endpoint (:create, :attach, :start,
    #            :stop, :wait, :delete, :build).
    # *args    - Any arguments for building the URI (container ID). If the last
    #            argument is a hash, it will be used to populate the query
    #            portion of the URI.
    #
    # Returns a URI string.
    def uri(endpoint, *args)
      query = URI.encode_www_form( args.last.is_a?(Hash) ? args.pop : {} )
      path  = sprintf API_PATHS[endpoint], *args

      URI::HTTP.build(:path => path, :query => query).request_uri
    end

    # Private: Docker multiplexes stdout/stderr over the same socket. This code
    # demuxes it and returns the combined streams.
    def demux_streams(input)
      output = ""
      until input.empty?
        header = input.slice!(0,8)
        stream_id, payload_length = header.unpack "L<L>"
        output << input.slice!(0, payload_length)
      end
      output
    end
  end
end
