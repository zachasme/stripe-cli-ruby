# stripe-cli-ruby

A self-contained Stripe CLI executable, wrapped up in a ruby gem. Includes a puma plugin to forward Stripe webhook events to your web server.

The binary distribution part is lifted from https://github.com/flavorjones/tailwindcss-ruby.

## Installation

This gem wraps the [Stripe CLI executable](https://github.com/stripe/stripe-cli). These executables are platform specific, so there are actually separate underlying gems per platform, but the correct gem will automatically be picked for your platform.

Supported platforms are:

- `arm64-darwin` (macos-arm64)
- `x86_64-darwin` (macos-x64)
- `x86_64-linux` (linux-x64)
- `arm64-linux` (linux-arm64)

Install the gem and add to the application's Gemfile by executing:

```
bundle add stripe-cli-ruby --group development
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install stripe-cli-ruby
```

> [!NOTE]
> Add the [included puma plugin](#forwarding-events-to-your-web-server) in order to listen for webhook events in development.

## Usage

### Ruby

The gem makes available `StripeCLI.executable` which is the path to the vendored standalone executable.

```ruby
require "stripe-cli-ruby"
StripeCLI.executable
# => "/path/to/gems/stripe-cli-ruby-1.33.0-x86_64-linux/exe/x86_64-linux/stripe"
```

### Command line

This gem provides an executable `stripe` shim that will run the vendored standalone executable.

```bash
# where is the shim?
$ bundle exec which stripe
/path/to/installs/ruby/3.3/bin/stripe

# run the actual executable through the shim
$ bundle exec stripe --version
stripe version 1.33.0
```

## Forwarding events to your web server

Make sure `Stripe.api_key` is set, e.g. in `config/initializers/stripe.rb`:

```ruby
Stripe.api_key = "sk_test_..."
```

Add `plugin :stripe` to `puma.rb` configuration:

```ruby
# Run stripe cli only in development.
plugin :stripe if ENV["RAILS_ENV"] == "development"
```

By default, events will be forwarded to `/stripe_events`, this can be configured using `stripe_forward_to "/stripe/webhook"` in `puma.rb`.

You can grab your *signing secret* using `StripeCLI.signing_secret`. For example:

```ruby
# config/environments/development.rb
config.stripe_signing_secret = StripeCLI.signing_secret(Stripe.api_key)

# app/controllers/stripe_events_controller.rb
class StripeEventsController < ActionController::API
  before_action :set_event

  def create
    case event.type
    when 'payment_intent.succeeded'
      payment_intent = event.data.object
      # ...
    end

    head :ok
  end

  private

    def event
      @event ||= Stripe::Webhook.construct_event(
        request.body.read,
        request.headers["stripe-signature"],
        Rails.configuration.stripe_signing_secret
      )
    rescue => error
      logger.error error
      head :bad_request
    end
end
```

## Development

Run `bin/setup` to install dependencies, `bundle exec rake download` to fetch the Stripe CLI binaries, and `bundle exec rake test` to run the tests. Set `TEST_STRIPE_API_KEY` to a test-mode key to run the tests that talk to Stripe.

## Releases

Releases are automatic:

1. The `update` workflow checks for a new Stripe CLI release every day. When there is one, the workflow bumps `StripeCLI::VERSION` and `StripeCLI::Upstream::VERSION` and pushes the commit to `main`.
2. The `ci` workflow tests every push to `main`, builds a gem per platform, and installs each one on its platform.
3. When `StripeCLI::VERSION` isn't tagged yet, `ci` pushes the gems to rubygems.org with [trusted publishing](https://guides.rubygems.org/trusted-publishing/) and creates a GitHub release.

To ship a fix without a new Stripe CLI version, bump `StripeCLI::VERSION` to something like `1.33.0.1` and push to `main`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zachasme/stripe-cli-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
