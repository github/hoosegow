require_relative '../lib/hoosegow'

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

describe Hoosegow::Docker do
  before do
    ::Docker.url = nil
    ::Docker.options = nil
  end

  context 'volumes' do
    subject { described_class.new(:volumes => volumes) }

    context 'unspecified' do
      subject { described_class.new }
      its(:volumes_for_create) { should be_empty }
      its(:volumes_for_bind) { should be_empty }
    end

    context 'empty' do
      let(:volumes) { {} }
      its(:volumes_for_create) { should be_empty }
      its(:volumes_for_bind) { should be_empty }
    end

    context 'with volumes' do
      let(:volumes) { {
        "/inside/path" => "/home/burke/data-for-container:rw",
        "/other/path" => "/etc/shared-config",
      } }
      its(:volumes_for_create) { should == {
        "/inside/path" => {},
        "/other/path" => {},
      } }
      its(:volumes_for_bind) { should == [
        "/home/burke/data-for-container:/inside/path:rw",
        "/etc/shared-config:/other/path:ro",
      ] }
    end
  end

  context 'docker_url' do
    it "correctly generates TCP urls" do
      hoosegow = Hoosegow::Docker.new CONFIG.merge(:host => "1.1.1.1", :port => 1234)
      expect(::Docker.url).to eq("tcp://1.1.1.1:1234")
    end

    it "correctly generates Unix urls" do
      hoosegow = Hoosegow::Docker.new CONFIG.merge(:socket => "/path/to/socket")
      expect(::Docker.url).to eq("unix:///path/to/socket")
    end
  end

  context "callbacks" do
    let(:cb) { lambda { |info|  } }

    it "calls after_create" do
      expect(cb).to receive(:call).with { |*args| args.first.is_a? Hash }
      docker = Hoosegow::Docker.new CONFIG.merge(:after_create => cb)
      begin
        docker.create_container CONFIG[:image_name]
      ensure
        docker.stop_container
        docker.delete_container
      end
    end

    it "calls after_start" do
      expect(cb).to receive(:call).with { |*args| args.first.is_a? Hash }
      docker = Hoosegow::Docker.new CONFIG.merge(:after_start => cb)
      begin
        docker.create_container CONFIG[:image_name]
        docker.start_container
      ensure
        docker.stop_container
        docker.delete_container
      end
    end

    it "calls after_stop" do
      expect(cb).to receive(:call).with { |*args| args.first.is_a? Hash }
      docker = Hoosegow::Docker.new CONFIG.merge(:after_stop => cb)
      begin
        docker.create_container CONFIG[:image_name]
        docker.start_container
      ensure
        docker.stop_container
        docker.delete_container
      end
    end
  end

  context "image_exist?" do
    it "returns true if the image exists" do
      docker = Hoosegow::Docker.new CONFIG
      expect(docker.image_exist?(CONFIG[:image_name])).to eq(true)
    end

    it "returns false if the image doesn't exist" do
      docker = Hoosegow::Docker.new CONFIG
      expect(docker.image_exist?("not_there")).to eq(false)
    end
  end

  context "delete_container" do
    let(:docker) { Hoosegow::Docker.new CONFIG }
    let(:container) { Object.new }
    before do
      docker.instance_variable_set(:@container, container)
      allow(container).to receive(:id).and_return("1234")
      $old_stderr = $stderr
      $stderr = StringIO.new
    end
    after do
      $stderr = $old_stderr
    end

    it "rescues error and prints when error is raised" do
      allow(container).to receive(:delete).
        and_raise(::Docker::Error::ServerError, "device or resource busy")
      docker.delete_container
      $stderr.rewind
      expect($stderr.read).to eql("Docker could not delete 1234: device or resource busy\n")
    end
  end
end
