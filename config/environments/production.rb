require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.public_file_server.enabled = true

  config.logger     = ActiveSupport::Logger.new($stdout)
  config.log_level  = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_tags   = [:request_id]
  # SSL is terminated at the host's ingress.
  config.force_ssl  = false

  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  # Sign-in codes go out through Resend's HTTP API (AuthEmail).
  Resend.api_key = ENV["RESEND_API_KEY"]
  config.action_mailer.delivery_method   = :resend
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host:     ENV.fetch("APP_HOST", "localhost"),
    protocol: "https",
  }

  config.secret_key_base = ENV["SECRET_KEY_BASE"]

  config.hosts = nil
end
