require 'hoosegow/convict/reverse'
require 'json'

class Hoosegow
  class Convict
    class << self
      def render(data)
        data = JSON.load(data)
        type = data["type"]
        args = data["args"]
        send "render_#{type}", *args
      end
    end
  end
end
