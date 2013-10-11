require './lib/hoosegow'
require 'stringio'

class Hoosegow
  def render_foobar
    "foobar"
  end
end

def build_file(*args)
  data = JSON.dump *args
  data += "\n"
  StringIO.new data
end

describe Hoosegow, "#proxy_receive" do
  it "calls appropriate render method" do
    hoosegow = Hoosegow.new :no_proxy => true
    file = build_file :name => "render_reverse", :args => ["foobar"]
    hoosegow.proxy_receive(file).should eq("raboof")
  end
end

describe Hoosegow, "#proxy_send" do
  it "calls appropriate render method via proxy" do
    hoosegow = Hoosegow.new :prebuilt => true
    hoosegow.proxy_send("render_reverse","foobar").should eq("raboof")
  end
end

describe Hoosegow, "render_*" do
  it "runs directly if in docker" do
    hoosegow = Hoosegow.new :no_proxy => true
    hoosegow.stub :proxy_send => "not raboof"
    hoosegow.render_reverse("foobar").should eq("raboof")
  end

  it "runs via proxy if not in docker" do
    hoosegow = Hoosegow.new :prebuilt => true
    hoosegow.stub :proxy_send => "not raboof"
    hoosegow.render_reverse("foobar").should eq("not raboof")
  end

  it "can be monkey patched" do
    hoosegow = Hoosegow.new :prebuilt => true
    hoosegow.render_foobar.should eq("foobar")
  end
end
