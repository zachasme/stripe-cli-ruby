# stripe-cli-ruby

The [Stripe CLI](https://github.com/stripe/stripe-cli) as a Ruby gem, plus a Puma plugin that forwards Stripe webhooks to your app in development.

The gem's version matches the Stripe CLI version it ships. A new Stripe CLI release gets a new gem within a day.

## Installation

```bash
bundle add stripe-cli-ruby --group development
```

Bundler picks the gem for your platform, which includes the `stripe` binary. Supported platforms:

- `arm64-darwin` (macOS on Apple silicon)
- `x86_64-darwin` (macOS on Intel)
- `aarch64-linux` (Linux on ARM)
- `x86_64-linux` (Linux on x86, glibc and musl)

## Webhooks in development

The Puma plugin starts `stripe listen` when Puma boots and stops it when Puma stops. You don't need `stripe login` or a second terminal.

1. Set `Stripe.api_key`. The plugin passes it to the Stripe CLI. The plugin also needs the [stripe gem](https://github.com/stripe/stripe-ruby).

    ```ruby
    # config/initializers/stripe.rb
    Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
    ```

2. Add the plugin to `config/puma.rb`:

    ```ruby
    plugin :stripe if ENV.fetch("RAILS_ENV", "development") == "development"
    ```

3. Verify webhooks with the Stripe CLI's signing secret:

    ```ruby
    # config/environments/development.rb
    config.x.stripe.signing_secret = StripeCLI.signing_secret(Stripe.api_key)

    # config/environments/production.rb
    config.x.stripe.signing_secret = Rails.application.credentials.dig(:stripe, :signing_secret)
    ```

    ```ruby
    # config/routes.rb
    post "stripe_events", to: "stripe_events#create"

    # app/controllers/stripe_events_controller.rb
    class StripeEventsController < ActionController::API
      def create
        event = Stripe::Webhook.construct_event(
          request.body.read,
          request.headers["Stripe-Signature"],
          Rails.configuration.x.stripe.signing_secret
        )

        case event.type
        when "payment_intent.succeeded"
          payment_intent = event.data.object
          # ...
        end

        head :ok
      rescue JSON::ParserError, Stripe::SignatureVerificationError
        head :bad_request
      end
    end
    ```

`StripeCLI.signing_secret` returns `nil` when the Stripe CLI can't get a secret, for example when the API key is wrong.

### Choosing events

By default the plugin forwards every snapshot event (the regular kind, not [thin events](https://docs.stripe.com/event-destinations#thin-events)) to `/stripe_events`. Change the path in `config/puma.rb`:

```ruby
stripe_forward_to "/stripe/webhooks"
```

Or forward the webhook endpoints you set up in the Stripe dashboard:

```ruby
stripe_use_configured_webhooks
```

Each dashboard endpoint then gets only the events it listens to, at its own path on your app. An endpoint at `https://example.com/stripe/webhooks` gets forwarded to `http://localhost:3000/stripe/webhooks`. The Stripe CLI exits if the account doesn't have any webhook endpoints in test mode. Stripe also sends real deliveries to the endpoint's URL, so point it at a server that answers, like staging. Otherwise Stripe disables the endpoint after a few days of failures.

## Running the Stripe CLI

The gem adds a `stripe` command:

```bash
bundle exec stripe trigger payment_intent.succeeded
```

From Ruby, `StripeCLI.executable` returns the binary's path:

```ruby
StripeCLI.executable
# => "/path/to/gems/stripe-cli-ruby-<version>-x86_64-linux/exe/x86_64-linux/stripe"
```

## Development

Run `bin/setup` to install dependencies, `bundle exec rake download` to fetch the Stripe CLI binaries, and `bundle exec rake test` to run the tests. Set `TEST_STRIPE_API_KEY` to a test mode key to run the tests that talk to Stripe. The dashboard test also needs an enabled webhook endpoint for `customer.created` on that account, and skips without one.

## Releases

Releases are automatic:

1. The `update` workflow checks for a new Stripe CLI release every day. When there is one, the workflow bumps `StripeCLI::VERSION` and `StripeCLI::Upstream::VERSION` and pushes the commit to `main`.
2. The `ci` workflow tests every push to `main`, builds a gem per platform, and installs each one on its platform.
3. When `StripeCLI::VERSION` isn't tagged yet, `ci` pushes the gems to rubygems.org with [trusted publishing](https://guides.rubygems.org/trusted-publishing/) and creates a GitHub release.

To ship a fix without a new Stripe CLI version, add a fourth number to `StripeCLI::VERSION`, like `1.54.1.1`, and push to `main`.

## License

The gem is available under the [MIT License](LICENSE.txt). The Stripe CLI is under the [Apache License 2.0](LICENSE-DEPENDENCIES). The packaging is based on [tailwindcss-ruby](https://github.com/flavorjones/tailwindcss-ruby).
