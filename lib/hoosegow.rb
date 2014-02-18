require_relative 'hoosegow/docker'
require_relative 'hoosegow/exceptions'

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
    options = options.dup
    @no_proxy = options.delete(:no_proxy)
    @inmate_dir  = options.delete(:inmate_dir) || '/hoosegow/inmate'
    @image_name = options.delete :image_name
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

  # Public: Proxies method call to instance running in a Docker container.
  #
  # name - The method to call in the Docker instance.
  # args - Arguments that should be passed to the Docker instance method.
  #
  # Returns the return value from the Docker instance method.
  def proxy_send(name, args)
    data = MessagePack.pack [name, args]
    result = docker.run_container image_name, data
    MessagePack.unpack result
  end

  # Public: Receives proxied method call from the non-Docker instance.
  #
  # pipe - The pipe that the method call will come in on.
  #
  # Returns the return value of the specified function.
  def proxy_receive(pipe)
    name, args = MessagePack.unpack(pipe)
    result = send name, *args
    MessagePack.pack(result)
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
        define_singleton_method name do |*args|
          proxy_send name, args
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
    JSON.parse docker.inspect_image(image_name)
    true
  rescue JSON::ParserError
    false
  end

  # Public: Build a Docker image from the Dockerfile in the root directory of
  # the gem.
  #
  # Returns build output text. Raises ImageBuildError if there is a problem.
  def build_image(&block)
    docker.build_image image_name, tarball, &block
  end

  # Private: The name of the docker image to use. If not specified manually,
  # this will be infered from the hash of the tarball.
  #
  # Returns string image name.
  def image_name
    @image_name || (tarball && @image_name)
  end

  private
  # Private: Get or create a Docker instance.
  #
  # Returns an Docker instance.
  def docker
    @docker ||= Docker.new @docker_options
  end

  # Tarball of this gem and the inmate file. Used for building an image.
  #
  # Returns string tarball.
  def tarball
    return @tarball if defined? @tarball

    Dir.mktmpdir do |tmpdir|
      # Copy Hoosegow gem to tmpdir
      hoosegow_dir = File.expand_path(File.dirname(__FILE__) + '/..')
      hoosegow_files = Dir[ File.join(hoosegow_dir, '*') ]
      hoosegow_files.select! { |f| !f.start_with? '.' }
      FileUtils.cp_r hoosegow_files, tmpdir

      # Copy inmate files to the `inmate` dir.
      if @inmate_dir
        tmp_inmate = FileUtils.mkdir(File.join(tmpdir, 'inmate'))[0]
        inmate_files = Dir[ File.join(@inmate_dir, '*') ]
        FileUtils.cp_r inmate_files, tmp_inmate
      end

      # Find hash of all files we're sending over.
      digest = Digest::SHA1.new
      Dir[File.join(tmpdir, '**/*')].each do |path|
        if File.file? path
          open path, 'r' do |file|
            digest.update file.read
          end
        end
      end
      @image_name = "hoosegow:#{digest.hexdigest}"

      # Create tarball of the tmpdir.
      stdout, stderr, status = Open3.capture3 'tar', '-c', '-C', tmpdir, '.'

      raise Hoosegow::ImageBuildError, stderr unless stderr.empty?

      @tarball = stdout
    end
  end

  # Returns true if we are in the Docker instance or are in develpment mode.
  #
  # Returns true/false.
  def no_proxy?
    !!@no_proxy
  end
end
