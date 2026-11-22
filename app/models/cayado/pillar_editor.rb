module Cayado
  class PillarEditor < ApplicationRecord
    belongs_to :pillar
    belongs_to :membership, class_name: "::Membership"

    validates :membership_id, uniqueness: { scope: :pillar_id }
    validate { must_belong_to_church(:membership, membership, pillar&.vision&.church) }
  end
end
