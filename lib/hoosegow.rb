require 'hoosegow/convict'
require 'hoosegow/guard'

class Hoosegow
  class << self
    attr_accessor :docker_host, :docker_port, :docker_image, :development
  end
end

# Host where docker is running.
Hoosegow.docker_host  = '127.0.0.1'
# Port where docker is running.
Hoosegow.docker_port  = 4243
# Name of docker image to use for containers.
Hoosegow.docker_image = 'hoosegow'
# Development mode. If true, Guard sends calls directly to Convict rather than
# going through docker.
Hoosegow.development  = false
