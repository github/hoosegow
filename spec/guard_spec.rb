require './lib/hoosegow'

describe Hoosegow::Guard, "#render" do
  it "runs docker container" do
    Hoosegow::Guard.render_reverse("foobar").should eq("raboof")
  end

  it "runs Convict methods directly in development mode" do
    Hoosegow.development = true
    Hoosegow::Convict.stub :render_reverse => "not raboof"
    Hoosegow::Guard.render_reverse("foobar").should eq("not raboof")
    Hoosegow.development = false
  end

  it "proxies call if unless in development mode" do
    Hoosegow::Convict.stub :render_reverse => "not raboof"
    Hoosegow::Guard.render_reverse("foobar").should eq("raboof")
  end
end