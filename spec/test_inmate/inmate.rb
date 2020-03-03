class Hoosegow
  module Inmate
    def render_reverse(s)
      yield :test if block_given?
      s.reverse
    end
  end
end
