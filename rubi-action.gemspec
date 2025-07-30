# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "rubi-action"
  spec.version       = "0.1.6"
  spec.authors       = ["nyanrus"]

  spec.summary       = "A Ruby gem for GitHub Actions helper and automation."
  spec.description   = "Provides helpers and DSLs for building GitHub Actions and automating workflows in Ruby."
  spec.homepage      = "https://github.com/nyanrus/rubi-action"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "README.md", "LICENSE.txt", "bin/*"]
  spec.require_paths = ["lib"]
  spec.executables << "rubi-action"

  spec.add_runtime_dependency "rake"
  # Add other dependencies as needed
end
