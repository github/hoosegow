require './lib/hoosegow'

describe Hoosegow, "#render" do
  it "understand reverse type" do
    data = JSON.dump :type => 'reverse', :file => 'foobar'
    hoosegow = Hoosegow.new data
    hoosegow.render.should eq('raboof')
  end
end