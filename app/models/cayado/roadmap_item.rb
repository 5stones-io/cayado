module Cayado
  # Something on the Roadmap that isn't a sermon series: a major event, an
  # outreach or a ministry initiative. (Series sit in their own lane, read
  # straight from SermonSeries, so their dates live in one place.)
  class RoadmapItem < ApplicationRecord
    LANES = {
      "sermon_series"       => "Sermon Series",
      "major_event"         => "Major Events",
      "outreach"            => "Outreach",
      "ministry_initiative" => "Ministry Initiatives",
    }.freeze
    ITEM_LANES = LANES.keys - ["sermon_series"]

    belongs_to :church
    belongs_to :owner_membership, class_name: "::Membership", optional: true
    belongs_to :pillar, optional: true
    belongs_to :move, optional: true
    has_many :attachments, as: :attachable, dependent: :destroy

    before_validation { self.pillar = move.pillar if move && pillar.nil? }

    validates :title, :starts_on, :ends_on, presence: true
    validates :lane, inclusion: { in: ITEM_LANES, message: "must be major_event, outreach or ministry_initiative" }
    validates :color, inclusion: { in: Ministry::COLORS }
    validate :ends_after_start
    validate { must_belong_to_church(:owner_membership, owner_membership, church) }
    validate { must_belong_to_church(:pillar, pillar, church) }
    validate { must_belong_to_church(:move, move, church) }
    validate :move_under_pillar

    # Anything that touches the year, not only what starts in it.
    scope :in_year, ->(year) { where(starts_on: ..Date.new(year, 12, 31), ends_on: Date.new(year, 1, 1)..) }

    private

    def ends_after_start
      return if starts_on.nil? || ends_on.nil? || ends_on >= starts_on

      errors.add(:ends_on, "must be on or after the start date")
    end

    def move_under_pillar
      return if move.nil? || pillar.nil? || move.pillar_id == pillar_id

      errors.add(:move, "isn't one of that pillar's moves")
    end
  end
end
