require_relative '../lib/hoosegow/docker'

describe Hoosegow::Docker do
  context 'volumes' do
    subject { described_class.new(:volumes => volumes) }

    context 'unspecified' do
      subject { described_class.new }
      its(:volumes_for_create) { should be_nil }
      its(:volumes_for_bind) { should be_nil }
    end

    context 'empty' do
      let(:volumes) { {} }
      its(:volumes_for_create) { should be_empty }
      its(:volumes_for_bind) { should be_empty }
    end

    context 'with volumes' do
      let(:volumes) { {"/inside/path" => "/home/burke/data-for-container", "/other/path" => "/etc/shared-config"} }
      its(:volumes_for_create) { should == {"/inside/path" => {}, "/other/path" => {}} }
      its(:volumes_for_bind) { should == ["/home/burke/data-for-container:/inside/path:rw", "/etc/shared-config:/other/path:rw"] }
    end
  end
end
