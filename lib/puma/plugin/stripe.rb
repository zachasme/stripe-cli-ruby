# frozen_string_literal: true

require "puma"
require "puma/plugin"
require "stripe"
require "stripe_cli"

Puma::Plugin.create do
  def start(launcher)
    @launcher = launcher

    launcher.events.on_booted do
      if use_configured_webhooks?
        launcher.log_writer.log "Stripe: forwarding webhooks configured in the dashboard to #{forward_to}"
      else
        launcher.log_writer.log "Stripe: forwarding webhooks to #{forward_to}"
      end
      @pid = spawn(StripeCLI.executable, "listen", "--all-snapshot", *("--use-configured-webhooks" if use_configured_webhooks?), "--forward-to", forward_to.to_s, "--api-key", Stripe.api_key.to_s)
    rescue StripeCLI::UnsupportedPlatformException, StripeCLI::ExecutableNotFoundException, Errno::ENOENT => e
      launcher.log_writer.log "[Stripe] Could not start the Stripe CLI: #{e.message}"
    end

    launcher.events.on_stopped { stop_stripe }
  end

  private
    def stop_stripe
      return unless @pid

      @launcher.log_writer.log "[Stripe] Stopping..."
      Process.kill(:INT, @pid)
      Process.wait(@pid)
    rescue Errno::ECHILD, Errno::ESRCH
    end

    def use_configured_webhooks?
      @launcher.options[:stripe_use_configured_webhooks]
    end

    # Dashboard endpoints bring their own paths, so only the host and port are ours.
    def forward_to
      _, port, host = @launcher.binder.ios.first.addr
      if use_configured_webhooks?
        URI::HTTP.build(port:, host:)
      else
        URI::HTTP.build(port:, host:, path: @launcher.options.fetch(:stripe_forward_to, "/stripe_events"))
      end
    end
end

module Puma
  class DSL
    def stripe_forward_to(path)
      @options[:stripe_forward_to] = path
    end

    def stripe_use_configured_webhooks(enabled = true)
      @options[:stripe_use_configured_webhooks] = enabled
    end
  end
end
