require 'hoosegow/convict'
require 'hoosegow/docker'

class Hoosegow
  def self.method_missing(name, *args)
    if name =~ /^render_(.+)$/
      data = JSON.dump :type => $1, :args => args
      run_convict data
    else
      super
    end
  end

  def self.run_convict(data)
    docker.run data
  end

  def self.docker
    @docker ||= Docker.new '192.168.171.129', 4243, 'hoosegow'
  end
end
