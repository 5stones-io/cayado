module Cayado
  module Api
    module V1
      # A year's Sundays (anyone on staff reads; admins type them in until
      # Planning Center does). Named by date: /weekly_metrics/2026-03-01.
      class WeeklyMetricsController < BaseController
        include Cayado::HealthJson
        include Cayado::YearParam

        before_action :require_admin!, only: [:update, :destroy]
        before_action :parse_week_of, only: [:update, :destroy]

        def index
          metrics = Current.church.weekly_metrics.between(Date.new(year, 1, 1)..Date.new(year, 12, 31))
          render json: { year: year, weekly_metrics: metrics.map { weekly_metric_json(_1) } }
        end

        # Creates or corrects the Sunday; only the fields sent change.
        def update
          metric = Current.church.weekly_metrics.find_or_initialize_by(week_of: @week_of)
          created = metric.new_record?
          metric.assign_attributes(metric_params.merge(source: "manual"))
          return render_errors(metric) unless metric.save

          render json: weekly_metric_json(metric), status: created ? :created : :ok
        end

        def destroy
          Current.church.weekly_metrics.find_by!(week_of: @week_of).destroy!
          head :no_content
        end

        private

        def parse_week_of
          @week_of = Date.iso8601(params[:week_of])
        rescue Date::Error
          render json: { error: "That isn't a date", code: "invalid_date" }, status: :unprocessable_content
        end

        def metric_params
          permitted = params.permit(:attendance, :first_time_guests, :giving_cents, :label, by_ministry: [:name, :value])
          permitted[:by_ministry] = permitted[:by_ministry].map(&:to_h) if permitted.key?(:by_ministry)
          permitted.to_h
        end
      end
    end
  end
end
