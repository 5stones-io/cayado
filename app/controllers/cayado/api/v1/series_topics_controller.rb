module Cayado
  module Api
    module V1
      # Admin: which topics a series carries, and how heavily. A PUT replaces
      # them all; a weight of 0 (or blank) leaves that topic out. All or
      # nothing: one bad weight and the old ones stay.
      class SeriesTopicsController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!

        def update
          series = Current.church.sermon_series.find(params[:sermon_series_id])
          invalid = nil
          SeriesTopic.transaction do
            # Old rows go first, so re-weighting a topic isn't a duplicate.
            series.series_topics.delete_all
            weights.each do |topic_id, weight|
              row = SeriesTopic.new(sermon_series: series, topic_id: topic_id, weight: weight)
              next if row.save

              invalid = row
              raise ActiveRecord::Rollback
            end
          end
          return render_errors(invalid) if invalid

          render json: { id: series.id, weights: series_weights_json(series.reload) }
        end

        private

        def weights
          raw = params[:weights].respond_to?(:to_unsafe_h) ? params[:weights].to_unsafe_h : {}
          raw.transform_values(&:to_i).reject { |_, w| w.zero? }
        end
      end
    end
  end
end
