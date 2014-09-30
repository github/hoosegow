require 'rake'

Gem::Specification.new do |s|
  s.name        = 'hoosegow'
  s.version     = '1.0.1'
  s.summary     = "A Docker jail for native rendering code"
  s.authors     = ["Ben Toews"]
  s.email       = 'mastahyeti@github.com'
  globs = %w[
    README.md
    Gemfile
    Rakefile
    Dockerfile
    hoosegow.gemspec
    docs/**/*
    lib/**/*
    script/**/*
    spec/**/*
  ]
  s.files       = Dir[*globs]
  s.executables = ['hoosegow']
  s.homepage    = 'https://github.com/github/hoosegow'
  s.add_development_dependency 'rspec', '2.14.1'
  s.add_runtime_dependency     'msgpack'
  s.add_runtime_dependency     'yajl-ruby', '>= 1.1.0', '~> 1.1'
end
