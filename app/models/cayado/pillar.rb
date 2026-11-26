module Cayado
  # Reach / Disciple / Send. Tone picks its color on the Vision screen.
  class Pillar < ApplicationRecord
    TONES = %w[ink sage terracotta].freeze

    belongs_to :vision
    has_many :moves, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :pillar
    has_many :pillar_editors, dependent: :destroy
    has_many :editors, through: :pillar_editors, source: :membership

    validates :title, presence: true
    validates :tone, inclusion: { in: TONES }

    scope :for_church, ->(church) { joins(:vision).where(cayado_visions: { church_id: church.id }) }

    # Admins edit every pillar; anyone else only the pillars they're named
    # an editor on.
    def editable_by?(membership)
      return false if membership.nil?

      membership.admin_or_owner? || pillar_editors.any? { _1.membership_id == membership.id }
    end
  end
end
