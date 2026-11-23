module Cayado
  module Api
    module V1
      # The Roadmap screen: one year, four lanes. The series lane is read
      # from the church's sermon series; the other three are roadmap items.
      class RoadmapController < BaseController
        include Cayado::PlanningJson
        include Cayado::YearParam

        def show
          series = Current.church.sermon_series.in_year(year)
                                 .includes(:weeks, :attachments, owner_membership: :account, move: :pillar)
                                 .order(:starts_on, :id)
          items = Current.church.roadmap_items.in_year(year)
                                .includes(:attachments, :pillar, :move, owner_membership: :account)
                                .order(:starts_on, :id).group_by(&:lane)

          lanes = RoadmapItem::LANES.map do |key, name|
            bars = key == "sermon_series" ? series.map { roadmap_series_json(_1) } : (items[key] || []).map { roadmap_item_json(_1) }
            { key: key, name: name, items: bars }
          end
          render json: { year: year, lanes: lanes }
        end
      end
    end
  end
end
