require_relative 'lib/hoosegow'

require 'rspec/core/rake_task'

begin
	require_relative 'config'
rescue LoadError
	CONFIG = {
    :inmate_dir => File.join(File.dirname(__FILE__), 'spec', 'test_inmate')
  }
end

RSpec::Core::RakeTask.new(:spec)
Rake::Task[:spec].prerequisites << :bootstrap_if_changed
task :default => :spec

# Takes md5sum of current directory's contents.
def directory_md5
  `find . -not -path './.*' -and -not -name '.*' -type f -print0 | xargs -0 md5sum | md5sum`
end

# Checks if there have been changes to
def directory_changed?
  current = directory_md5
  !File.exists?('.md5sum') || current != File.read('.md5sum')
end

def write_md5
  File.write '.md5sum', directory_md5
end

def hoosegow
  @hoosgow ||= Hoosegow.new CONFIG
end

desc "Benchmark render_reverse run in docker"
task :benchmark => :bootstrap_if_changed do
  10.times do |i|
    sleep 0.5
    start = Time.now
    hoosegow.render_reverse "foobar"
    puts "render_reverse run ##{i} took #{Time.now - start} seconds"
  end
  hoosegow.cleanup
end

desc "Bootstrap docker if the directory has changed since last bootstrap"
task :bootstrap_if_changed do
  if directory_changed?
    Rake::Task[:bootstrap_docker].invoke
  end
end

desc "Building docker image."
task :bootstrap_docker do
  hoosegow.build_image
  write_md5
end
