# frozen_string_literal: true

require "puma"
require "puma/plugin"
require "stripe"
require "stripe_cli"

Puma::Plugin.create do
  def start(launcher)
    @launcher = launcher

    launcher.events.on_booted do
      launcher.log_writer.log "Stripe: forwarding webhooks to #{forward_to}"
      @pid = spawn(StripeCLI.executable, "listen", "--all-snapshot", "--forward-to", forward_to.to_s, "--api-key", Stripe.api_key.to_s)
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

    def forward_to
      path = @launcher.options.fetch(:stripe_forward_to, "/stripe_events")
      _, port, host = @launcher.binder.ios.first.addr
      URI::HTTP.build(port:, host:, path:)
    end
end

module Puma
  class DSL
    def stripe_forward_to(path)
      @options[:stripe_forward_to] = path
    end
  end
end
