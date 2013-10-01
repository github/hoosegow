Dir[File.join(File.dirname(__FILE__), 'hoosegow/*.rb')].each { |f| require f }
require 'json'

class Hoosegow
  def initialize(data)
    @json_data = JSON.load(data)
    @type      = @json_data.delete "type"
  end

  def render
    render_method = "render_#{@type}"
    if respond_to? render_method
      send render_method
    else
      raise NotImplementedError
    end
  end
end
