module Cayado
  # One ministry's plan for one week. No row means the slot is awaiting.
  class AlignmentPlan < ApplicationRecord
    belongs_to :sermon_week
    belongs_to :ministry
    belongs_to :updated_by_membership, class_name: "::Membership", optional: true

    validates :body, presence: true
    validates :ministry_id, uniqueness: { scope: :sermon_week_id }
    validate { must_belong_to_church(:ministry, ministry, sermon_week&.church) }
  end
end
