require 'rake'

Gem::Specification.new do |s|
  s.name        = 'hoosegow'
  s.version     = '1.0.0'
  s.summary     = "A Docker jail for native rendering code"
  s.authors     = ["Ben Toews"]
  s.email       = 'mastahyeti@github.com'
  files = `git ls-tree -rz --name-only HEAD`.split("\0")
  files.reject! { |f| f.start_with?(".") }
  files.reject! { |f| f.end_with?(".gemspec") }
  files.reject! { |f| f.start_with?("Gemfile") }
  files.reject! { |f| f.start_with?("bin/") } # These are included by listing 'executables'
  s.files       = files
  s.executables = ['hoosegow']
  s.homepage    = 'https://github.com/github/hoosegow'
  s.add_development_dependency 'rspec'
  s.add_runtime_dependency     'msgpack'
  s.add_runtime_dependency     'yajl-ruby'
end
