require 'hoosegow/docker'

class Hoosegow
  class Guard
    class << self
      # Public: Proxies method call to Convict running in a Docker container.
      #
      # args - Arguments that should be passed tothe Convict method.
      #
      # Returns the return value from the Convict method.
      def proxy_send(name, args)
        unless Hoosegow.development
          data = JSON.dump :name => name, :args => args
          Hoosegow.docker.run data
        else
          Hoosegow::Convict.send name, *args
        end
      end

      private
      # Internal: Simplifies the calling of proxy_send by allowing Convict
      # methods to be called on the Guard class.
      def method_missing(name, *args)
        proxy_send name, args
      end
    end
  end
end
