module Cayado
  module Api
    module V1
      # The Vision screen. GET is null until the church has one; an admin
      # writes it with PUT (created the first time).
      class VisionsController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!, only: [:update]

        def show
          vision = Vision.includes(horizon_years: [], pillars: [{ pillar_editors: { membership: :account } },
                                                                { moves: %i[sermon_series roadmap_items] }])
                         .find_by(church: Current.church)
          render json: vision && vision_json(vision)
        end

        def update
          vision = Vision.find_or_initialize_by(church: Current.church)
          created = vision.new_record?
          vision.assign_attributes(params.permit(:title, :subtitle, :start_year, :end_year))
          return render_errors(vision) unless vision.save

          render json: vision_json(vision), status: created ? :created : :ok
        end
      end
    end
  end
end
