require 'rspec/core/rake_task'

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

desc "Bootstrap docker if the directory has changed since last bootstrap"
task :bootstrap_if_changed do
  if directory_changed?
    Rake::Task[:bootstrap_docker].invoke
    write_md5
  end
end

desc "Build docker image"
task :bootstrap_docker do
  sh 'docker -H :4243 pull ubuntu'
  sh 'docker -H :4243 build -t=hoosegow .'
end
