require 'json'
require 'hoosegow/convict/reverse'

class Hoosegow
  class Convict
    def initialize(data)
      @json_data = JSON.load(data)
      @type      = @json_data.delete "type"
    end

    def render
      send "render_#{@type}"
    end
  end
end
