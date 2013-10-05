require 'hoosegow/docker'

class Hoosegow
  class Guard
    class << self
      def method_missing(name, *args)
        if name =~ /^render_(.+)$/
          data = JSON.dump :type => $1, :args => args
          docker.run data
        else
          super
        end
      end

      def docker
        @docker ||= Docker.new Hoosegow.docker_host, Hoosegow.docker_port, Hoosegow.docker_image
      end
    end
  end
end
