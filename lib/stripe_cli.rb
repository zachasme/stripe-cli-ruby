# frozen_string_literal: true

require_relative "stripe_cli/signing_secret"
require_relative "stripe_cli/upstream"
require_relative "stripe_cli/version"

module StripeCLI
  DEFAULT_DIR = File.expand_path(File.join(__dir__, "..", "exe"))
  GEM_NAME = "stripe-cli-ruby"

  # raised when the host platform is not supported by upstream stripe's binary releases
  class UnsupportedPlatformException < StandardError
  end

  # raised when the stripe cli executable could not be found where we expected it to be
  class ExecutableNotFoundException < StandardError
  end

  class << self
    def platform
      [ :cpu, :os ].map { |m| Gem::Platform.local.send(m) }.join("-")
    end

    def executable(exe_path: DEFAULT_DIR)
      if StripeCLI::Upstream::NATIVE_PLATFORMS.keys.none? { |p| Gem::Platform.match_gem?(Gem::Platform.new(p), GEM_NAME) }
        raise UnsupportedPlatformException, <<~MESSAGE
          #{GEM_NAME} does not support the #{platform} platform.
          Install the Stripe CLI another way: https://docs.stripe.com/stripe-cli#install
        MESSAGE
      end

      exe_file = Dir.glob(File.expand_path(File.join(exe_path, "*", "stripe"))).find do |f|
        Gem::Platform.match_gem?(Gem::Platform.new(File.basename(File.dirname(f))), GEM_NAME)
      end

      if exe_file.nil? || !File.exist?(exe_file)
        raise ExecutableNotFoundException, <<~MESSAGE
          Cannot find the stripe cli executable for #{platform} in #{exe_path}

          If you're using bundler, please make sure you're on the latest bundler version:

              gem install bundler
              bundle update --bundler

          Then make sure your lock file includes this platform by running:

              bundle lock --add-platform #{platform}
              bundle install

          See `bundle lock --help` output for details.

          If you're still seeing this message after taking those steps, try running
          `bundle config` and ensure `force_ruby_platform` isn't set to `true`.
        MESSAGE
      end

      exe_file
    end
  end
end
