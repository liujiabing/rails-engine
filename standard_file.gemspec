$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "standard_file/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "standard-file"
  s.version     = StandardFile::VERSION
  s.authors     = [""]
  s.email       = ["me@bitar.io"]
  s.homepage    = "https://standardnotes.org"
  s.summary     = "Standard File User & Sync Engine"
  s.description = "Standard File User & Sync Engine"
  s.license     = "GPLv3"

  # s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency "rails", "~> 5.0.1"
  s.add_dependency 'jwt'
  s.add_dependency "bcrypt", '~> 3.1'

end
