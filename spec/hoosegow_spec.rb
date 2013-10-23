require './lib/hoosegow'
require 'stringio'

begin
  require File.expand_path(File.dirname(__FILE__) + '/../config')
rescue LoadError
  CONFIG = {}
end

class Hoosegow
  def render_foobar
    "foobar"
  end
end

describe Hoosegow, "#proxy_receive" do
  it "calls appropriate render method" do
    hoosegow = Hoosegow.new CONFIG.merge(:no_proxy => true)
    hoosegow.proxy_receive("render_reverse", ["foobar"]).should eq("raboof")
  end
end

describe Hoosegow, "#proxy_send" do
  it "calls appropriate render method via proxy" do
    hoosegow = Hoosegow.new CONFIG
    hoosegow.proxy_send("render_reverse",["foobar"]).should eq("raboof")
  end
end

describe Hoosegow, "render_*" do
  it "runs directly if in docker" do
    hoosegow = Hoosegow.new CONFIG.merge(:no_proxy => true)
    hoosegow.stub :proxy_send => "not raboof"
    hoosegow.render_reverse("foobar").should eq("raboof")
  end

  it "runs via proxy if not in docker" do
    hoosegow = Hoosegow.new CONFIG
    hoosegow.stub :proxy_send => "not raboof"
    hoosegow.render_reverse("foobar").should eq("not raboof")
  end

  it "can be monkey patched" do
    hoosegow = Hoosegow.new CONFIG
    hoosegow.render_foobar.should eq("foobar")
  end
end
