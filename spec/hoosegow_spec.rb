require_relative '../lib/hoosegow'
require 'msgpack'

unless defined?(CONFIG)
  begin
    require_relative '../config'
  rescue LoadError
    CONFIG = {}
  end
end

inmate_dir = File.join(File.dirname(__FILE__), 'test_inmate')
CONFIG[:inmate_dir] = inmate_dir
CONFIG[:image_name] ||= Hoosegow.new(CONFIG).image_name

describe Hoosegow do
  context "no_proxy option" do
    it "runs directly if set" do
      hoosegow = Hoosegow.new CONFIG.merge(:no_proxy => true)
      hoosegow.stub :proxy_send => "not raboof"
      hoosegow.render_reverse("foobar").should eq("raboof")
    end

    it "runs via proxy if not set" do
      hoosegow = Hoosegow.new CONFIG
      hoosegow.stub :proxy_send => "not raboof"
      hoosegow.render_reverse("foobar").should eq("not raboof")
      hoosegow.cleanup
    end
  end

  context "image_exists?" do
    it "returns true for existing images" do
      hoosegow = Hoosegow.new CONFIG
      expect(hoosegow.image_exists?).to eq(true)
    end

    it "returns false for images that don't exist" do
      hoosegow = Hoosegow.new CONFIG.merge(:image_name => "not_there")
      expect(hoosegow.image_exists?).to eq(false)
    end
  end
end


describe Hoosegow::Protocol::Proxy do
  subject(:proxy) { Hoosegow::Protocol::Proxy.new(:yield => block, :stdout => stdout, :stderr => stderr) }
  let(:block) { double('block') }
  let(:stdout) { double('stdout') }
  let(:stderr) { double('stderr') }

  it "encodes the method call" do
    expect(MessagePack.unpack(proxy.encode_send(:method_name, ["arg1", {:name => 'value'}]))).to eq(['method_name', ["arg1", {'name' => 'value'}]])
  end

  it "decodes a yield" do
    block.should_receive(:call).with('a', 'b')
    proxy.receive(:stdout, MessagePack.pack([:yield, ['a', 'b']]))
  end

  context 'with no block' do
    let(:block) { nil }
    it "decodes a yield" do
      proxy.receive(:stdout, MessagePack.pack([:yield, ['a', 'b']]))
    end
  end

  it "decodes the return value" do
    proxy.receive(:stdout, MessagePack.pack([:return, 1]))
    expect(proxy.return_value).to eq(1)
  end

  it "decodes a known error class" do
    expect { proxy.receive(:stdout, MessagePack.pack([:raise, {:class => 'RuntimeError', :message => 'I went boom'}])) }.to raise_error(Hoosegow::InmateRuntimeError, "RuntimeError: I went boom")
  end

  it "decodes an error" do
    expect { proxy.receive(:stdout, MessagePack.pack([:raise, {:class => 'SomeInternalError', :message => 'I went boom'}])) }.to raise_error(Hoosegow::InmateRuntimeError, "SomeInternalError: I went boom")
  end

  it "decodes an error with a stack trace" do
    expect { proxy.receive(:stdout, MessagePack.pack([:raise, {:class => 'SomeInternalError', :message => 'I went boom', :backtrace => ['file.rb:33:in `example\'']}])) }.to raise_error(Hoosegow::InmateRuntimeError, "SomeInternalError: I went boom\nfile.rb:33:in `example'")
  end

  it "decodes stdout" do
    stdout.should_receive(:write).with('abc')
    proxy.receive(:stdout, MessagePack.pack([:stdout, 'abc']))
  end

  it "decodes stderr" do
    stderr.should_receive(:write).with('abc')
    proxy.receive(:stderr, 'abc')
  end

  it "decodes the return value, across several reads" do
    MessagePack.pack([:return, :abcdefghijklmn]).each_char do |char|
      proxy.receive(:stdout, char)
    end
    expect(proxy.return_value).to eq('abcdefghijklmn')
  end
end

describe Hoosegow::Protocol::Inmate do
  it "calls appropriate render method" do
    inmate = double('inmate')
    inmate.should_receive(:render).with('foobar').
      and_yield(:a, 1).
      and_yield(:b, 2, 3).
      and_return('raboof')

    stdin = StringIO.new(MessagePack.pack(['render', ['foobar']]))
    stdout = StringIO.new
    stdout.set_encoding('BINARY')
    r,w = IO.pipe

    Hoosegow::Protocol::Inmate.run(:inmate => inmate, :stdin => stdin, :stdout => stdout, :intercepted => r)

    expect(stdout.string).to eq( MessagePack.pack([:yield, [:a, 1]]) + MessagePack.pack([:yield, [:b, 2, 3]]) + MessagePack.pack([:return, 'raboof']) )
  end

  it "encodes exceptions" do
    inmate = Object.new
    def inmate.render(s) ; raise 'boom' ; end

    stdin = StringIO.new(MessagePack.pack(['render', ['foobar']]))
    stdout = StringIO.new
    stdout.set_encoding('BINARY')
    r,w = IO.pipe

    Hoosegow::Protocol::Inmate.run(:inmate => inmate, :stdin => stdin, :stdout => stdout, :intercepted => r)

    unpacked_type, unpacked_data = MessagePack.unpack(stdout.string)
    expect(unpacked_type).to eq('raise')
    expect(unpacked_data).to include('class' => 'RuntimeError')
    expect(unpacked_data).to include('message' => 'boom')
    expect(unpacked_data['backtrace']).to be_a(Array)
    expect(unpacked_data['backtrace'].first).to eq("#{__FILE__}:#{__LINE__ - 14}:in `render'")
  end

  it "does not hang if stdin isn't closed" do
    # Use a pipe so that we have a not-closed IO
    stdin, feed_stdin = IO.pipe
    feed_stdin.write(MessagePack.pack(['render', ['foobar']]))

    inmate = double('inmate')
    inmate.should_receive(:render).with('foobar').and_return('raboof')
    stdout = StringIO.new
    stdout.set_encoding('BINARY')
    r,w = IO.pipe

    timeout(2) { Hoosegow::Protocol::Inmate.run(:inmate => inmate, :stdin => stdin, :stdout => stdout, :intercepted => r) }
  end

  it "encodes stdout" do
    inmate = double('inmate')
    inmate.should_receive(:render).with('foobar').and_return('raboof')

    stdin = StringIO.new(MessagePack.pack(['render', ['foobar']]))
    stdout = StringIO.new
    stdout.set_encoding('BINARY')
    stdout = PeekAtWrittenEncodings.new(stdout)
    r,w = IO.pipe
    w.set_encoding('BINARY')
    w.puts "STDOUT from somewhere"

    Hoosegow::Protocol::Inmate.run(:inmate => inmate, :stdin => stdin, :stdout => stdout, :intercepted => r)

    encoded_stdout = MessagePack.pack([:stdout, "STDOUT from somewhere\n"])
    encoded_return = MessagePack.pack([:return, 'raboof'])
    expect([encoded_stdout+encoded_return, encoded_return+encoded_stdout]).to include(stdout.string)
  end
  
  class PeekAtWrittenEncodings
    def initialize(io)
      @io = io
    end
    
    def write(s)
      $stderr.puts :string => s, :encoding => s.encoding
      @io.write(s)
    end
    
    def string
      @io.string
    end
  end
end
