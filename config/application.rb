require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"

Bundler.require(*Rails.groups)

module Cayado
  # This repo is both a mountable engine (Cayado::Engine, what cayado-cloud
  # and a self-hosted app use) and a standalone app, so the gem can run its
  # own specs against its own database. Same shape as the spirely gem.
  class Application < Rails::Application
    config.load_defaults 7.2

    config.api_only = false

    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore

    config.active_job.queue_adapter = Rails.env.production? ? :sidekiq : :async

    # config/routes.rb draws Cayado::Engine.routes (see the comment there),
    # so the standalone app mounts the engine to reach them, as a host app
    # does.
    initializer :mount_cayado_engine, after: :add_routing_paths do |app|
      app.routes.append do
        mount Cayado::Engine => "/"
      end
    end
  end
end
