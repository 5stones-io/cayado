# Cayado::Engine.routes.draw, not Rails.application.routes.draw: the engine
# and the standalone app (config/application.rb) share this directory, so
# both would load this file. Drawing onto the engine's own route set keeps
# it to one target; the standalone app mounts the engine to reach it.
# (Same as the spirely gem; its routes.rb explains the failure modes.)
Cayado::Engine.routes.draw do
  # Leading slash: Rails' own health controller, not Cayado::Rails::...
  get "/up", to: "/rails/health#show"

  # The church comes from the Host header (TenantResolution), not the path.
  # isolate_namespace prefixes Cayado:: on every controller below.
  namespace :api do
    namespace :v1 do
      # No sign-in: the sign-in screen shows which church it's for.
      resource :tenant,   only: [:show], controller: "tenant"
      resource :me,       only: [:show], controller: "me"
      resource :two_step, only: [:show], controller: "two_step"
    end
  end
end
