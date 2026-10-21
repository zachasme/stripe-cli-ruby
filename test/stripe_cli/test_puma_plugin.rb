# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "securerandom"
require "timeout"
require "puma"
require "puma/configuration"
require "puma/launcher"
require "stripe"

class StripeCLI::TestPumaPlugin < Minitest::Test
  def test_forwards_events
    skip "Skipping because TEST_STRIPE_API_KEY is not present" unless ENV.key? "TEST_STRIPE_API_KEY"

    assert_equal "/stripe_events", forwarded_path_for_new_customer
  end

  def test_forwards_events_to_dashboard_endpoints
    skip "Skipping because TEST_STRIPE_API_KEY is not present" unless ENV.key? "TEST_STRIPE_API_KEY"

    Stripe.api_key = ENV["TEST_STRIPE_API_KEY"]
    endpoint = Stripe::WebhookEndpoint.list.auto_paging_each.find do |e|
      e.status == "enabled" && (e.enabled_events & [ "*", "customer.created" ]).any?
    end
    skip "Skipping because the account has no webhook endpoint for customer.created" unless endpoint

    assert_equal URI(endpoint.url).path, forwarded_path_for_new_customer(configure: ->(c) { c.stripe_use_configured_webhooks })
  end

  def test_stops_cleanly_when_the_stripe_cli_is_missing
    tried = Queue.new
    StripeCLI.stub(:executable, -> { tried << true; raise StripeCLI::ExecutableNotFoundException, "missing" }) do
      run_puma { Timeout.timeout(10) { tried.pop } }
    end
  end

  private
    # Boots Puma with the plugin, creates a customer tagged with a fresh id, and returns
    # the path its customer.created event arrived at. Other test runs share the account,
    # so the tag tells this run's event apart from theirs.
    def forwarded_path_for_new_customer(configure: nil)
      Stripe.api_key = ENV["TEST_STRIPE_API_KEY"]
      secret = StripeCLI.signing_secret(Stripe.api_key)
      run_id = SecureRandom.uuid
      received = Queue.new

      app = lambda do |env|
        event = Stripe::Webhook.construct_event(env["rack.input"].read, env["HTTP_STRIPE_SIGNATURE"], secret)
        received << env["PATH_INFO"] if event.type == "customer.created" && event.data.object.metadata["test_run"] == run_id
        [ 200, {}, [ "ok" ] ]
      end

      run_puma(app, configure:) do
        sleep 5 # let stripe listen connect
        Stripe::Customer.create(metadata: { test_run: run_id })
        Timeout.timeout(20) { received.pop }
      end
    end

    def run_puma(app = ->(_env) { [ 200, {}, [ "ok" ] ] }, configure: nil)
      config = Puma::Configuration.new do |c|
        c.app app
        c.plugin "stripe"
        c.port 9292
        configure&.call(c)
      end
      launcher = Puma::Launcher.new(config)
      thread = Thread.new do
        Thread.current.abort_on_exception = true
        launcher.run
      end
      sleep 1 until launcher.binder.ios.any?

      yield
    ensure
      launcher&.stop
      thread&.join
    end
end
