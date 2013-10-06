require './lib/hoosegow'

describe Hoosegow::Convict, "#render" do
  it "calls appropriate render method" do
    data = JSON.dump :name => "render_reverse", :args => ["hello world"]
    Hoosegow::Convict.proxy_receive(data).should eq("dlrow olleh")
  end
end