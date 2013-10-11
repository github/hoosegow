require './lib/hoosegow/serialize'

include Hoosegow::Serialize

describe Hoosegow::Serialize, "#dump_method_call" do
  it "dumps arrays" do
    returned = dump_method_call "foobar", ["hello", "world"]
    expected = <<-EOS.gsub /^\s*/, ""
      {"name":"foobar","args":["hello","world"]}
    EOS
    returned.should eq(expected)
  end

  it "dumps hashes" do
    returned = dump_method_call "foobar", "qwer" => 345
    expected = <<-EOS.gsub /^\s*/, ""
      {"name":"foobar","args":{"qwer":345}}
    EOS
    returned.should eq(expected)
  end

  it "dumps nested objects" do
    returned = dump_method_call "foobar", "qwer" => [123, 234, {"asdf" => 345}]
    expected = <<-EOS.gsub /^\s*/, ""
      {"name":"foobar","args":{"qwer":[123,234,{"asdf":345}]}}
    EOS
    returned.should eq(expected)
  end

  it "dumps files" do
    file = open __FILE__
    size = file.size
    data = file.read
    file.seek 0

    returned = dump_method_call "foobar", file
    expected = <<-EOS.gsub /^\s*/, ""
      {"name":"foobar","args":{"_hoosegow_file":#{size}}}
    EOS
    expected += data
    file.close
    returned.should eq(expected)
  end
end
