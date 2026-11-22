require_relative "lib/cayado/version"

Gem::Specification.new do |spec|
  spec.name        = "cayado"
  spec.version     = Cayado::VERSION
  spec.authors     = ["Chad Singleton"]
  spec.email       = ["hello@5stones.io"]
  spec.summary     = "Vision, roadmap and sermon-alignment planner for a pastor and their exec team"
  spec.description = "Rails engine behind Cayado: churches, staff accounts with password and authenticator sign-in, " \
                     "and the planning API (vision, sermon series, ministry alignment, roadmap, church health)."
  spec.homepage    = "https://github.com/5stones-io/cayado"

  spec.metadata = {
    "source_code_uri" => "https://github.com/5stones-io/cayado",
  }

  spec.files = Dir[
    "app/**/*",
    "config/**/*",
    "db/**/*",
    "lib/**/*",
    "README.md"
  ]

  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.3"

  spec.add_dependency "rails",         "~> 7.2"
  spec.add_dependency "pg",            "~> 1.5"
  # json 3 removed `quirks_mode`, which Rails 7.2 still passes when it
  # renders JSON ("unknown keyword: quirks_mode").
  spec.add_dependency "json",          "~> 2.0"
  spec.add_dependency "rodauth-rails", "~> 1.0"
  spec.add_dependency "jwt"
  spec.add_dependency "bcrypt",        "~> 3.1"
  # Rodauth otp + recovery_codes: authenticator-app codes, and the QR code
  # shown while setting one up.
  spec.add_dependency "rotp"
  spec.add_dependency "rqrcode"
  spec.add_dependency "sidekiq",       "~> 7.0"
  spec.add_dependency "redis",         "~> 5.0"
  spec.add_dependency "rack-cors"
  spec.add_dependency "rack-attack"
  spec.add_dependency "resend"
end
