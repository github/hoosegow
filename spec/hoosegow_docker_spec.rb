require_relative '../lib/hoosegow/docker'

begin
  require_relative '../config'
rescue LoadError
  CONFIG = {}
end

CONFIG.merge! :inmate_dir => File.join(File.dirname(__FILE__), 'test_inmate')

describe Hoosegow::Docker do
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
end
