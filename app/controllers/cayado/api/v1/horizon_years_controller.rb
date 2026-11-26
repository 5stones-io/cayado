module Cayado
  module Api
    module V1
      # PUT/DELETE /api/v1/vision/years/:year: one rung of the year ladder,
      # named by its year. Admins only.
      class HorizonYearsController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!

        def update
          year = vision.horizon_years.find_or_initialize_by(year: params[:year].to_i)
          year.headline = params[:headline] if params.key?(:headline)
          # An empty list ([""] over a form post) clears the goals.
          year.goals = Array(params[:goals]).compact_blank if params.key?(:goals)
          return render_errors(year) unless year.save

          render json: year_json(year)
        end

        def destroy
          vision.horizon_years.find_by!(year: params[:year].to_i).destroy!
          head :no_content
        end

        private

        def vision
          @vision ||= Vision.find_by!(church: Current.church)
        end
      end
    end
  end
end
