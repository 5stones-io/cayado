module Cayado
  module Api
    module V1
      # GET /api/v1/vision: the Vision screen. null until the church has one.
      class VisionsController < BaseController
        include Cayado::PlanningJson

        def show
          vision = Vision.includes(horizon_years: [], pillars: [{ pillar_editors: { membership: :account } },
                                                                { moves: :sermon_series }])
                         .find_by(church: Current.church)
          return render json: nil if vision.nil?

          render json: {
            id: vision.id,
            title: vision.title,
            subtitle: vision.subtitle,
            start_year: vision.start_year,
            end_year: vision.end_year,
            pillars: vision.pillars.map { pillar_json(_1) },
            years: vision.horizon_years.map { { year: _1.year, headline: _1.headline, goals: _1.goals } },
          }
        end

        private

        def pillar_json(pillar)
          {
            id: pillar.id,
            title: pillar.title,
            blurb: pillar.blurb,
            tone: pillar.tone,
            can_edit: pillar.editable_by?(Current.membership),
            editors: pillar.pillar_editors.map { person_json(_1.membership) },
            moves: pillar.moves.map do |move|
              { id: move.id, text: move.text,
                sermon_series: move.sermon_series.sort_by(&:id).map { { id: _1.id, title: _1.title } } }
            end,
          }
        end
      end
    end
  end
end
