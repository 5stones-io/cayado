module Cayado
  module Api
    module V1
      # GET /api/v1/dashboard: "How are we, really?" Attendance, giving and
      # guests over the trailing year, from the weekly numbers.
      class DashboardController < BaseController
        include Cayado::HealthJson

        def show
          health = HealthStats.new(Current.church)
          render json: {
            as_of: health.as_of,
            stats: health.stats,
            weekly: health.weekly,
            by_ministry: health.by_ministry,
            monthly_giving: health.monthly_giving,
            budget: budget_json(health.budget),
          }
        end
      end
    end
  end
end
