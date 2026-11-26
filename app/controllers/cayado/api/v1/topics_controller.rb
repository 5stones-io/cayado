module Cayado
  module Api
    module V1
      # The Topics screen: each topic's weight month by month across the
      # year, from the series that carry it. Admins keep the library.
      class TopicsController < BaseController
        include Cayado::PlanningJson
        include Cayado::YearParam

        # More than this many weight-points in a year reads as "heavy".
        HEAVY_TOTAL = 6

        before_action :require_admin!, only: [:create, :update, :destroy]

        def index
          topics = Current.church.topics.to_a
          series = Current.church.sermon_series.in_year(year).includes(series_topics: :topic).order(:starts_on, :id).to_a
          months = topics.to_h { [_1.id, Array.new(12, 0)] }
          series.each do |s|
            touched = months_in_year(s)
            s.series_topics.each { |st| touched.each { months[st.topic_id][_1 - 1] += st.weight } }
          end

          render json: {
            year: year,
            topics: topics.map { topic_row(_1, months[_1.id]) },
            series: series.map { { id: _1.id, title: _1.title, starts_on: _1.starts_on, ends_on: _1.ends_on, weights: series_weights_json(_1) } },
          }
        end

        def create
          topic = Current.church.topics.new(name: params[:name])
          topic.position = (Current.church.topics.maximum(:position) || -1) + 1
          return render_errors(topic) unless topic.save

          render json: topic_json(topic), status: :created
        end

        def update
          topic = Current.church.topics.find(params[:id])
          return render_errors(topic) unless topic.update(params.permit(:name, :position))

          render json: topic_json(topic)
        end

        def destroy
          Current.church.topics.find(params[:id]).destroy!
          head :no_content
        end

        private

        def topic_json(topic) = { id: topic.id, name: topic.name, position: topic.position }

        def topic_row(topic, by_month)
          total = by_month.sum
          status = if total.zero? then "gap" elsif total >= HEAVY_TOTAL then "heavy" else "healthy" end
          topic_json(topic).merge(months: by_month, total: total, months_hit: by_month.count(&:positive?), status: status)
        end

        # The months of `year` a series runs through (1–12).
        def months_in_year(series)
          from = [series.starts_on, Date.new(year, 1, 1)].max
          to = [series.ends_on || series.starts_on, Date.new(year, 12, 31)].min
          (from.month..to.month).to_a
        end
      end
    end
  end
end
