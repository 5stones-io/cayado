module Cayado
  # The conversation on a sermon week. membership is nil once its author
  # has left the staff; the comment stays.
  class Comment < ApplicationRecord
    belongs_to :sermon_week
    belongs_to :membership, class_name: "::Membership", optional: true

    validates :body, presence: true
    validates :membership, presence: true, on: :create
    validate(on: :create) { must_belong_to_church(:membership, membership, sermon_week&.church) }

    def deletable_by?(member)
      member.present? && (member.admin_or_owner? || membership_id == member.id)
    end
  end
end
