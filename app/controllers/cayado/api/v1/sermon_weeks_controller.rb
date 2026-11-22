module Cayado
  module Api
    module V1
      # One week of a series (mobile's Week detail). Admins add, edit and
      # remove weeks.
      class SermonWeeksController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!, only: [:create, :update, :destroy]

        def show
          week = find_week
          render json: week_json(week, ministries: ministries).merge(
            series: { id: week.sermon_series.id, title: week.sermon_series.title },
            comments: week.comments.includes(membership: :account).map { comment_json(_1) }
          )
        end

        def create
          series = Current.church.sermon_series.find(params[:sermon_series_id])
          week = series.weeks.new(week_params)
          week.position = (series.weeks.maximum(:position) || 0) + 1 unless params.key?(:position)
          return render_errors(week) unless week.save

          render json: week_json(week, ministries: ministries), status: :created
        end

        def update
          week = find_week
          return render_errors(week) unless week.update(week_params)

          render json: week_json(week, ministries: ministries)
        end

        def destroy
          find_week.destroy!
          head :no_content
        end

        private

        def find_week
          SermonWeek.for_church(Current.church).find(params[:id])
        end

        def week_params
          params.permit(:position, :preached_on, :title, :scripture, :big_idea)
        end
      end
    end
  end
end
