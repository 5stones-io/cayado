module Cayado
  # A linked doc on a roadmap item or a sermon series (DocRow). Cayado
  # keeps the link, not the file.
  class Attachment < ApplicationRecord
    KINDS = %w[doc sheet slide folder].freeze
    # Google links say what they are; anything else takes the kind given.
    KIND_BY_URL = {
      %r{\Ahttps://docs\.google\.com/spreadsheets/} => "sheet",
      %r{\Ahttps://docs\.google\.com/presentation/} => "slide",
      %r{\Ahttps://docs\.google\.com/document/}     => "doc",
      %r{\Ahttps://drive\.google\.com/drive/(u/\d+/)?folders/} => "folder",
    }.freeze

    belongs_to :church
    belongs_to :attachable, polymorphic: true
    belongs_to :owner_membership, class_name: "::Membership", optional: true

    before_validation { self.church ||= attachable&.church }
    before_validation :read_kind_from_url

    validates :title, presence: true
    validates :url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http(s) link" }
    validates :kind, inclusion: { in: KINDS }
    validate { must_belong_to_church(:owner_membership, owner_membership, church) }

    # Whoever attached it, or an admin.
    def editable_by?(membership)
      return false if membership.nil?

      membership.admin_or_owner? || owner_membership_id == membership.id
    end

    private

    def read_kind_from_url
      return unless will_save_change_to_url?

      _, kind = KIND_BY_URL.find { |pattern, _| url.to_s.match?(pattern) }
      self.kind = kind if kind
    end
  end
end
