module Cayado
  # How heavily a series carries a topic: 1 (touches it) to 3 (it's the point).
  class SeriesTopic < ApplicationRecord
    WEIGHTS = (1..3)

    belongs_to :sermon_series
    belongs_to :topic

    validates :weight, inclusion: { in: WEIGHTS, message: "must be 1, 2 or 3" }
    validates :topic_id, uniqueness: { scope: :sermon_series_id }
    validate { must_belong_to_church(:topic, topic, sermon_series&.church) }
  end
end
