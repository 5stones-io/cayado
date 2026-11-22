module Cayado
  # A ministry that plans against each sermon week: one alignment slot.
  # Every church starts with DEFAULTS and can rename, recolor or add more.
  class Ministry < ApplicationRecord
    COLORS = %w[ink terracotta sage gold sky].freeze
    DEFAULTS = [
      { key: "kids",         name: "Kids",         color: "sky" },
      { key: "youth",        name: "Youth",        color: "terracotta" },
      { key: "small-groups", name: "Small Groups", color: "sage" },
      { key: "worship",      name: "Worship",      color: "gold" },
    ].freeze

    belongs_to :church
    belongs_to :lead_membership, class_name: "::Membership", optional: true
    has_many :alignment_plans, dependent: :destroy

    validates :name, presence: true
    validates :key, presence: true, uniqueness: { scope: :church_id },
                    format: { with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/ }
    validates :color, inclusion: { in: COLORS }
    validate { must_belong_to_church(:lead_membership, lead_membership, church) }

    def self.create_defaults!(church)
      DEFAULTS.each_with_index do |attrs, i|
        church.ministries.find_or_create_by!(key: attrs[:key]) do |m|
          m.assign_attributes(attrs.merge(position: i))
        end
      end
    end

    # The lead writes this ministry's plans; admins write anyone's.
    def plannable_by?(membership)
      return false if membership.nil?

      membership.admin_or_owner? || lead_membership_id == membership.id
    end
  end
end
