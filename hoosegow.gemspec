require 'rake'

Gem::Specification.new do |s|
  s.name        = 'hoosegow'
  s.version     = '0.1.0'
  s.summary     = "A Docker jail for native rendering code"
  s.authors     = ["Ben Toews"]
  s.email       = 'mastahyeti@github.com'
  s.files       = FileList['**/*'].to_a
  s.homepage    = 'https://github.com/github/hoosegow'
end