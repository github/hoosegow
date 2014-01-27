source 'https://rubygems.org'

gemspec

# Load dependency Gemfile if present.
deps_gemfile = File.join(File.dirname(__FILE__), 'deps', 'Gemfile')
if File.exist? deps_gemfile
  eval(IO.read(deps_gemfile), binding)
end
