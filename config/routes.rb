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

      # Who's on staff, for lead and editor pickers.
      resource :team, only: [:show], controller: "team"

      # Admins write the vision, its pillars and the year ladder; a pillar's
      # named editors also write that pillar and its moves.
      resource :vision, only: [:show, :update] do
        resources :pillars, only: [:create]
        resources :years, only: [:update, :destroy], param: :year, controller: "horizon_years"
      end
      resources :pillars, only: [:update, :destroy] do
        resources :moves, only: [:create]
      end
      resources :moves, only: [:update, :destroy]

      # Named by key (/ministries/kids), like the alignment slots.
      resources :ministries, only: [:index, :create, :update, :destroy], param: :key

      # The home screen: the Sunday ahead, what's coming, what needs an eye.
      resource :this_week, only: [:show], controller: "this_week"

      # What the rest of the team did (mobile Activity tab); seen marks it read.
      resource :activity, only: [:show], controller: "activity" do
        post :seen
      end

      resources :sermon_series, only: [:index, :show, :create, :update, :destroy] do
        resources :weeks, only: [:create], controller: "sermon_weeks"
        # Admin: preview (GET) and send (POST) a heads-up to the ministry leads.
        resource :notify, only: [:show, :create], controller: "notify"
      end
      resources :sermon_weeks, only: [:show, :update, :destroy] do
        # The slot is named by ministry key: /plans/kids.
        resources :plans, only: [:update, :destroy], param: :ministry_key, controller: "alignment_plans"
        resources :comments, only: [:create]
      end
      resources :comments, only: [:destroy]
    end
  end
end
