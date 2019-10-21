$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "standard_file/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "standard-file"
  s.version     = StandardFile::VERSION
  s.authors     = ["Standard File"]
  s.email       = ["me@bitar.io"]
  s.homepage    = "https://standardnotes.org"
  s.summary     = "Standard File User & Sync Engine"
  s.description = "Standard File allows for storage, sync, and encryption of items such as notes, tags, and any other models with a custom schema."
  s.license     = "GPL-3.0"

  s.add_dependency "rails"
  s.add_dependency 'jwt'
  s.add_dependency "bcrypt"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.require_paths = ["lib"]
end
