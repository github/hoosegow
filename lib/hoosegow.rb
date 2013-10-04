require 'hoosegow/convict'

class Hoosegow
  def self.method_missing(name, *args)
    if name =~ /^render_(.+)$/
      data = JSON.dump :type => $1, :args => args
    else
      super
    end
  end

  def run_convict(data)
    p data
  end
end
