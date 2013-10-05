require 'hoosegow/convict'
require 'hoosegow/guard'

class Hoosegow
  class << self
    attr_accessor :docker_host, :docker_port, :docker_image
  end
end

Hoosegow.docker_host  = 'localhost'
Hoosegow.docker_port  = 4243
Hoosegow.docker_image = 'hoosegow'
