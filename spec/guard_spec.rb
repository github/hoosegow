require './lib/hoosegow'

describe Hoosegow::Guard, "#render" do
  it "runs docker container" do
    Hoosegow::Guard.render_reverse("what the fuck?").should eq("?kcuf eht tahw")
  end
end