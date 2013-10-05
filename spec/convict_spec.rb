require './lib/hoosegow'

describe Hoosegow::Convict, "#render" do
  it "calls appropriate render method" do
    data = JSON.dump :type => "reverse", :args => ["hello world"]
    Hoosegow::Convict.render(data).should eq("dlrow olleh")
  end
end