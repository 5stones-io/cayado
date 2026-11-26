module Cayado
  # Who's in the room, as aggregates only: households, life-stage mix and
  # the last 90 days' season markers (births, funerals…). Pinned to sermon
  # weeks so the preacher sees it while planning.
  class CongregationSnapshot < ApplicationRecord
    include NamedNumbers

    belongs_to :church
    has_many :pinned_weeks, -> { order(:preached_on, :id) }, class_name: "Cayado::SermonWeek",
                                                              dependent: :nullify, inverse_of: :congregation_snapshot

    validates :taken_on, presence: true
    validates :households, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :source, inclusion: { in: WeeklyMetric::SOURCES }
    validates_named_numbers :life_stages, name_key: "label", number_key: "pct", range: 0..100
    validates_named_numbers :season_markers, name_key: "label", number_key: "count"

    scope :latest_first, -> { order(taken_on: :desc, id: :desc) }
  end
end
