# Bundler.require only loads what a Gemfile names, not a gem's own
# dependencies, so load what the engine needs here, for the standalone app
# and for any host app.
require "rodauth-rails"
require "jwt"
require "rotp"
require "rqrcode"
require "rack/attack"
require "rack/cors"
require "resend"
require "sidekiq"

require "cayado/version"
require "cayado/engine"

module Cayado
end
