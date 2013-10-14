require 'hoosegow/serialize'
require 'hoosegow/render'
require 'hoosegow/docker'
require 'json'

class Hoosegow
  include Render
  include Serialize

  # Initialize a Hoosegow instance.
  #
  # options -
  #           :no_proxy - Development mode. Use this if you don't want to setup
  #                       docker on your development instance, but still need
  #                       to test rendering files. This is how Hoosegow runs
  #                       inside the docker instance.
  #           :socket   - Path to Unix socket where Docker daemon is running.
  #                       (optional. defaults to "/var/run/docker.sock")
  #           :host     - IP or hostname where Docker daemon is running. Don't
  #                       set this if Docker is listening locally on a Unix
  #                       socket.
  #           :port     - TCP port where Docker daemon is running. Don't set
  #                       this if Docker is listening locally on a Unix socket.
  def initialize(options = {})
    return if @no_proxy = options[:no_proxy]
    @docker_options = {:host => options[:host],
                       :port => options[:port],
                       :socket => options[:socket]}
  end

  # Proxies method call to instance running in a docker container.
  #
  # name - The method to call in the docker instance.
  # args - Arguments that should be passed to the docker instance method.
  #
  # Returns the return value from the docker instance method.
  def proxy_send(name, args)
    data = dump_method_call name, args
    docker.run data
  end

  # Receives proxied method call from the non-docker instance.
  #
  # data - JSON hash specifying method name and arguments.
  #
  # Returns the return value of the specified function.
  def proxy_receive(pipe)
    data = read_method_call pipe
    send data["name"], *data["args"]
  end

  # Build a docker image from the Dockerfile in the root directory of the gem.
  #
  # Returns build output text.
  def build_image
    base_dir = File.expand_path(File.dirname(__FILE__) + '/..')
    tar = `tar -cC #{base_dir} .`
    docker.build tar
  end

  # Docker instance.
  def docker
    @docker ||= Docker.new @docker_options
  end

  # Returns true if we are in the docker instance or are in develpment mode.
  def no_proxy?
    @no_proxy == true
  end
end
