module Cayado
  module Api
    module V1
      # The Sermons screen: series, their weeks and each week's alignment
      # slots. Everyone on staff reads; admins create and edit series.
      class SermonSeriesController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!, only: [:create, :update, :destroy]
        before_action :set_series, only: [:show, :update, :destroy]

        def index
          series = Current.church.sermon_series
                                 .includes(:weeks, owner_membership: :account, move: :pillar)
                                 .order(Arel.sql("starts_on NULLS LAST"), :id)
          render json: { series: series.map { series_json(_1) } }
        end

        def show
          weeks = @series.weeks.includes(:comments, alignment_plans: { updated_by_membership: :account })
          render json: series_json(@series).merge(weeks: weeks.map { week_json(_1, ministries: ministries) })
        end

        def create
          series = Current.church.sermon_series.new(series_params)
          return render_errors(series) unless series.save

          render json: series_json(series), status: :created
        end

        def update
          return render_errors(@series) unless @series.update(series_params)

          render json: series_json(@series)
        end

        def destroy
          @series.destroy!
          head :no_content
        end

        private

        def set_series
          @series = Current.church.sermon_series.find(params[:id])
        end

        def series_params
          params.permit(:title, :theme, :scripture, :starts_on, :ends_on, :owner_membership_id, :move_id)
        end
      end
    end
  end
end
