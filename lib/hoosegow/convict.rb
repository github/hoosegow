require 'hoosegow/convict/reverse'
require 'json'

class Hoosegow
  class Convict
    class << self
      # Public: Receives proxied method call from Guard.
      #
      # data - JSON hash specifying method name and arguments.
      #
      # Returns the return value of the specified function.
      def proxy_receive(data)
        data = JSON.load(data)
        send data["name"], *data["args"]
      end
    end
  end
end
