require 'rake'

Gem::Specification.new do |s|
  s.name        = 'hoosegow'
  s.version     = '1.0.0'
  s.summary     = "A Docker jail for native rendering code"
  s.authors     = ["Ben Toews"]
  s.email       = 'mastahyeti@github.com'
  s.files       = FileList['**/*'].to_a
  s.homepage    = 'https://github.com/github/hoosegow'
  s.add_development_dependency 'rspec'
  s.add_runtime_dependency     'msgpack'
  s.add_runtime_dependency     'yajl-ruby'
end
