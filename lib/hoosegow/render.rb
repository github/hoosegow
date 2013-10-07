require 'hoosegow/render/reverse'

class Hoosegow
  module Render
    instance_methods.each do |name|
      old = instance_method name

      define_method name do |*args|
        if no_proxy?
          old.bind(self).call *args
        else
          proxy_send name, args
        end
      end
    end
  end
end
