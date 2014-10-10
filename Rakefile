require_relative 'lib/hoosegow'

require 'rspec/core/rake_task'

begin
  require_relative 'config'
rescue LoadError
  CONFIG = {}
end

inmate_dir = File.join(File.dirname(__FILE__), 'spec', 'test_inmate')
CONFIG[:inmate_dir] = inmate_dir
CONFIG[:image_name] = Hoosegow.new(CONFIG).image_name

RSpec::Core::RakeTask.new(:spec)
Rake::Task[:spec].prerequisites << :bootstrap_docker
task :default => :spec

def hoosegow
  @hoosgow ||= Hoosegow.new CONFIG
end

desc "Benchmark render_reverse run in docker"
task :benchmark => :bootstrap_docker do
  10.times do |i|
    sleep 0.5
    start = Time.now
    hoosegow.render_reverse "foobar"
    puts "render_reverse run ##{i} took #{Time.now - start} seconds"
  end
  hoosegow.cleanup
end

desc "Building docker image."
task :bootstrap_docker do
  hoosegow.build_image unless hoosegow.image_exists?
end
