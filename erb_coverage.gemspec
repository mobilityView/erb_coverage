$:.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "erb_coverage"
  s.version     = "0.0.1"
  s.authors     = ["mobilityView (James Roscoe)"]
  s.email       = ["james.roscoe@mobilityview.com"]
  s.homepage    = "http://github.com/mobilityView/erb_coverage"
  s.summary     = "Extend Ruby Coverage.result to include .erb view templates"
  s.description = "Add gem 'erb_coverage', git: 'https://github.com/mobilityView/erb_coverage' to your Gemfile"
  s.add_dependency 'rails', '~>5.1'

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  # s.test_files = Dir["test/**/*"]
end
