module Cayado
  # A concrete commitment under a pillar. Series (and later roadmap items)
  # say which move they advance.
  class Move < ApplicationRecord
    belongs_to :pillar
    has_many :sermon_series, class_name: "Cayado::SermonSeries", dependent: :nullify

    validates :text, presence: true

    scope :for_church, ->(church) { joins(pillar: :vision).where(cayado_visions: { church_id: church.id }) }
  end
end
