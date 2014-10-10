require 'rake'

Gem::Specification.new do |s|
  s.name        = 'hoosegow'
  s.version     = '1.1.0'
  s.summary     = "A Docker jail for ruby code"
  s.description = "Hoosegow provides an RPC layer on top of Docker containers so that you can isolate unsafe parts of your application."
  s.authors     = ["Ben Toews", "Matt Burke"]
  s.email       = 'mastahyeti@github.com'
  s.licenses    = ["MIT"]
  globs = %w[
    README.md
    LICENSE
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
  s.required_ruby_version = ">= 2.1.2"
  s.add_development_dependency 'rake'#,       '>= 0.6.9',  '~> 0.6'
  s.add_development_dependency 'rspec',      '>= 2.14.1', '~> 2.14'
  s.add_runtime_dependency     'msgpack',    '>= 0.5.6',  '~> 0.5'
  s.add_runtime_dependency     'yajl-ruby',  '>= 1.1.0',  '~> 1.1'
  s.add_runtime_dependency     'docker-api', '~> 1.13.6'
end
