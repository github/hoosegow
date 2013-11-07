require_relative 'hoosegow/docker'
require 'msgpack'

class Hoosegow
  # Initialize a Hoosegow instance.
  #
  # options -
  #           :no_proxy - Development mode. Use this if you don't want to setup
  #                       docker on your development instance, but still need
  #                       to test rendering files. This is how Hoosegow runs
  #                       inside the docker container.
  #           :socket   - Path to Unix socket where Docker daemon is running.
  #                       (optional. defaults to "/var/run/docker.sock")
  #           :host     - IP or hostname where Docker daemon is running. Don't
  #                       set this if Docker is listening locally on a Unix
  #                       socket.
  #           :port     - TCP port where Docker daemon is running. Don't set
  #                       this if Docker is listening locally on a Unix socket.
  def initialize(options = {})
    return if @no_proxy = options.delete(:no_proxy)
    @docker_options = options
  end

  # Proxies method call to instance running in a docker container.
  #
  # name - The method to call in the docker instance.
  # args - Arguments that should be passed to the docker instance method.
  #
  # Returns the return value from the docker instance method.
  def proxy_send(name, args)
    base = File.basename(@@deps_dir)
    data = MessagePack.pack [name, args, base]
    result = docker.run data
    MessagePack.unpack(result)
  end

  # Receives proxied method call from the non-docker instance.
  #
  # pipe - The pipe that the method call will come in on.
  #
  # Returns the return value of the specified function.
  def proxy_receive(pipe)
    name, args, base = MessagePack.unpack(pipe)

    if base
      deps = File.expand_path File.join(__FILE__, '../../', base)
      self.class.load_deps deps
    end

    result = send name, *args
    MessagePack.pack(result)
  end

  # Build a docker image from the Dockerfile in the root directory of the gem.
  #
  # Returns build output text.
  def self.build_image(docker_options)
    docker = Docker.new docker_options
    base_dir = File.expand_path(File.dirname(__FILE__) + '/..')
    cmd = "tar -cC #{base_dir} ."

    parent = File.dirname @@deps_dir
    base   = File.basename @@deps_dir
    cmd << "| tar -cC #{parent} #{base} @-"

    tar = `#{cmd}`
    docker.build tar
  end

  def self.load_deps(dir)
    @@deps_dir  = dir
    old_methods = instance_methods
    files = Dir.entries @@deps_dir
    files.map!    { |f| File.join @@deps_dir, f }
    files.select! { |f| File.file? f }
    files.each    { |f| require f }
    new_methods = instance_methods - old_methods

    new_methods.each do |name|
      old = instance_method name
      define_method name do |*args|
        if no_proxy?
          old.bind(self).call *args
        else
          proxy_send name, args
        end
      end
    end
  end

  private
  # Docker instance.
  def docker
    @docker ||= Docker.new @docker_options
  end

  # Returns true if we are in the docker instance or are in develpment mode.
  def no_proxy?
    !!@no_proxy
  end
end
