require_relative 'hoosegow/docker'
require_relative 'hoosegow/exceptions'
require_relative 'hoosegow/image_bundle'
require_relative 'hoosegow/protocol'

require 'msgpack'

class Hoosegow
  # Public: Initialize a Hoosegow instance.
  #
  # options -
  #           :no_proxy   - Development mode. Use this if you don't want to
  #                         setup Docker on your development instance, but
  #                         still need to test rendering files. This is how
  #                         Hoosegow runs inside the Docker container.
  #           :inmate_dir - Dependency directory to be coppied to the hoosegow
  #                         image. This should include a file called
  #                         `inmate.rb` that defines a Hoosegow::Inmate module.
  #           :image_name - The name of the Docker image to use. If this isn't
  #                         specified, we will infer the image name from the
  #                         hash the files present.
  #           :socket     - Path to Unix socket where Docker daemon is running.
  #                         (optional. defaults to "/var/run/docker.sock")
  #           :host       - IP or hostname where Docker daemon is running.
  #                         Don't set this if Docker is listening locally on a
  #                         Unix socket.
  #           :port       - TCP port where Docker daemon is running. Don't set
  #                         this if Docker is listening locally on a Unix
  #                         socket.
  def initialize(options = {})
    options         = options.dup
    @no_proxy       = options.delete(:no_proxy)
    @inmate_dir     = options.delete(:inmate_dir) || '/hoosegow/inmate'
    @image_name     = options.delete(:image_name)
    @docker_options = options
    load_inmate_methods

    # Don't want to have to require these in the container.
    unless no_proxy?
      require 'tmpdir'
      require 'fileutils'
      require 'open3'
      require 'digest'
    end
  end

  # Public: The thing that defines which files go into the docker image tarball.
  def image_bundle
    @image_bundle ||=
      Hoosegow::ImageBundle.new.tap do |image|
        image.add(File.expand_path('../../*', __FILE__), :ignore_hidden => true)
        image.add(File.join(@inmate_dir, "*"), :prefix => 'inmate')
      end
  end

  # Public: Proxies method call to instance running in a Docker container.
  #
  # name  - The method to call in the Docker instance.
  # args  - Arguments that should be passed to the Docker instance method.
  # block - A block that can be yielded to.
  #
  # See docs/dispatch.md for more information.
  #
  # Returns the return value from the Docker instance method.
  def proxy_send(name, args, &block)
    proxy = Hoosegow::Protocol::Proxy.new(
      :stdout => $stdout,
      :stderr => $stderr,
      :yield  => block
    )
    encoded_send = proxy.encode_send(name, args)
    docker.run_container(image_name, encoded_send) do |type, msg|
      proxy.receive(type, msg)
    end

    proxy.return_value
  end

  # Public: Load inmate methods from #{inmate_dir}/inmate.rb and hook them up
  # to proxied to the Docker container. If we are in the container, the methods
  # are loaded and setup to be called directly.
  #
  # Returns nothing. Raises InmateImportError if there is a problem.
  def load_inmate_methods
    inmate_file = File.join @inmate_dir, 'inmate.rb'

    unless File.exist?(inmate_file)
      raise Hoosegow::InmateImportError, "inmate file doesn't exist"
    end

    require inmate_file

    unless Hoosegow.const_defined?(:Inmate) && Hoosegow::Inmate.is_a?(Module)
      raise Hoosegow::InmateImportError,
        "inmate file doesn't define Hoosegow::Inmate"
    end

    if no_proxy?
      self.extend Hoosegow::Inmate
    else
      inmate_methods = Hoosegow::Inmate.instance_methods
      inmate_methods.each do |name|
        define_singleton_method name do |*args, &block|
          proxy_send name, args, &block
        end
      end
    end
  end

  # Public: We create/start a container after every run to reduce latency. This
  # needs to be called before the process ends to cleanup that remaining
  # container.
  #
  # Returns nothing.
  def cleanup
    docker.stop_container
    docker.delete_container
  end

  # Check if the Docker image exists.
  #
  # Returns true/false.
  def image_exists?
    docker.inspect_image(image_name)
    true
  rescue ::Docker::Error::NotFoundError
    false
  end

  # Public: Build a Docker image from the Dockerfile in the root directory of
  # the gem.
  #
  # Returns build output text. Raises ImageBuildError if there is a problem.
  def build_image(&block)
    docker.build_image image_name, image_bundle.tarball, &block
  end

  # Private: The name of the docker image to use. If not specified manually,
  # this will be infered from the hash of the tarball.
  #
  # Returns string image name.
  def image_name
    @image_name || image_bundle.image_name
  end

  private
  # Private: Get or create a Docker instance.
  #
  # Returns an Docker instance.
  def docker
    @docker ||= Docker.new @docker_options
  end

  # Returns true if we are in the Docker instance or are in develpment mode.
  #
  # Returns true/false.
  def no_proxy?
    !!@no_proxy
  end
end
