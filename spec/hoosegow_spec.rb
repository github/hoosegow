require_relative '../lib/hoosegow'
require 'msgpack'

begin
  require_relative '../config'
rescue LoadError
  CONFIG = {}
end

CONFIG.merge! :inmate_dir => File.join(File.dirname(__FILE__), 'test_inmate')

describe Hoosegow, "#proxy_receive" do
  it "calls appropriate render method" do
    hoosegow = Hoosegow.new CONFIG.merge(:no_proxy => true)
    data = MessagePack.pack(["render_reverse", ["foobar"]])
    result = hoosegow.proxy_receive(data)
    MessagePack.unpack(result).should eq("raboof")
  end
end

describe Hoosegow, "#proxy_send" do
  it "calls appropriate render method via proxy" do
    hoosegow = Hoosegow.new CONFIG
    hoosegow.proxy_send("render_reverse",["foobar"]).should eq("raboof")
    hoosegow.cleanup
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
    hoosegow.cleanup
  end
end
