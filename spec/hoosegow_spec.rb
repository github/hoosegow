require './lib/hoosegow'

describe Hoosegow, "#render" do
  it "understand reverse type" do
    data = JSON.dump :type => 'reverse', :args => ['foobar']
    Hoosegow::Convict.render(data).should eq('raboof')
  end
end