module Cayado
  # A concrete commitment under a pillar. Series (and later roadmap items)
  # say which move they advance.
  class Move < ApplicationRecord
    belongs_to :pillar
    has_many :sermon_series, class_name: "Cayado::SermonSeries", dependent: :nullify

    validates :text, presence: true
  end
end
