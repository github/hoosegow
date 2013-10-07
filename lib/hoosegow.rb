require 'hoosegow/convict'
require 'hoosegow/guard'

class Hoosegow
  class << self
    attr_writer :docker_host, :docker_port, :docker_image, :development

    def build_container
      base_dir = File.expand_path(File.dirname(__FILE__) + '/..')
      tar = `tar -cC #{base_dir} .`
      docker.build docker_image, tar
    end

    def docker
      @docker ||= Docker.new docker_host, docker_port, docker_image
    end

    def docker_host
      @docker_host || '127.0.0.1'
    end

    def docker_port
      @docker_port || 4243
    end

    def docker_image
      @docker_image || 'hoosegow'
    end

    def development
      @development || false
    end
  end
end
