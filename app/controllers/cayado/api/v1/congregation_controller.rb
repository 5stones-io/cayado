module Cayado
  module Api
    module V1
      # GET /api/v1/congregation: "Know the room." The latest snapshot and
      # the headline numbers. Aggregates only, never people.
      class CongregationController < BaseController
        include Cayado::HealthJson

        def show
          health = HealthStats.new(Current.church)
          snapshot = Current.church.congregation_snapshots.latest_first.first
          render json: {
            stats: { avg_attendance: health.avg_attendance, **health.first_time_guests, households: snapshot&.households },
            snapshot: snapshot_json(snapshot),
          }
        end
      end
    end
  end
end
