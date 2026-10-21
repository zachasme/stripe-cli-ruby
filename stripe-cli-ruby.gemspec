# frozen_string_literal: true

require_relative "lib/stripe_cli/version"

Gem::Specification.new do |spec|
  spec.name = "stripe-cli-ruby"
  spec.version = StripeCLI::VERSION
  spec.authors = [ "Zacharias Knudsen" ]
  spec.email = [ "z@chari.as" ]

  spec.summary = "A self-contained `stripe` executable."
  spec.homepage = "https://github.com/zachasme/stripe-cli-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "LICENSE-DEPENDENCIES", "README.md"]
  spec.bindir = "exe"
  spec.executables << "stripe"
  spec.require_paths = [ "lib" ]

  spec.add_development_dependency "puma", "~> 6.0" # see https://github.com/puma/puma/issues/3724
  spec.add_development_dependency "stripe"

  spec.add_development_dependency "rubocop-rails-omakase"
end
