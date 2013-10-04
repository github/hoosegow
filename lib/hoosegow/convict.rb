require 'hoosegow/convict/reverse'
require 'json'

class Hoosegow
  class Convict
    def self.render(data)
      data = JSON.load(data)
      type = data["type"]
      args = data["args"]
      
      new.send "render_#{type}", *args
    end
  end
end
