$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/lib')
require 'hoosegow'
require 'rspec/core/rake_task'

begin
	require File.expand_path(File.dirname(__FILE__) + '/config')
rescue LoadError
	CONFIG = {}
end

RSpec::Core::RakeTask.new(:spec)
Rake::Task[:spec].prerequisites << :bootstrap_if_changed
task :default => :spec

# Takes md5sum of current directory's contents.
def directory_md5
  `find . -not -path './.*' -and -not -name '.*' -type f -print0 | xargs -0 md5 | md5`
end

# Checks if there have been changes to
def directory_changed?
  current = directory_md5
  !File.exists?('.md5sum') || current != File.read('.md5sum')
end

def write_md5
  File.write '.md5sum', directory_md5
end

desc "Benchmark render_reverse run in docker"
task :benchmark => :bootstrap_if_changed do
  start = Time.now
  hoosegow = Hoosegow.new CONFIG
  instantiated = Time.now
  puts "Instantiated Hoosegow in #{instantiated - start} seconds"

  hoosegow.docker.start
  prepared = Time.now
  puts "Prepared Docker run in #{prepared - instantiated } seconds"

  sleep 1

  hoosegow.render_reverse "foobar"
  ran = Time.now
  puts "Ran render_reverse in #{ran - prepared - 1} seconds"
end

desc "Bootstrap docker if the directory has changed since last bootstrap"
task :bootstrap_if_changed do
  if directory_changed?
    Rake::Task[:bootstrap_docker].invoke
  end
end

desc "Building docker image."
task :bootstrap_docker do
  Hoosegow.new(CONFIG).build_image
  write_md5
end