# frozen_string_literal: true

require "open3"

module StripeCLI
  def self.signing_secret(api_key)
    secret, status = Open3.capture2(executable, "listen", "--api-key", api_key.to_s, "--print-secret", err: File::NULL)
    secret.chomp if status.success? && !secret.strip.empty?
  rescue
    nil
  end
end
