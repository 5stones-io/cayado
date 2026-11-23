module Cayado
  class SermonSeries < ApplicationRecord
    self.table_name = "cayado_sermon_series"

    belongs_to :church
    belongs_to :owner_membership, class_name: "::Membership", optional: true
    belongs_to :move, optional: true
    has_many :weeks, -> { order(:position, :preached_on) }, class_name: "Cayado::SermonWeek",
                                                            dependent: :destroy, inverse_of: :sermon_series
    has_many :series_topics, dependent: :delete_all
    has_many :attachments, as: :attachable, dependent: :destroy

    scope :in_year, lambda { |year|
      where(starts_on: ..Date.new(year, 12, 31))
        .where("COALESCE(cayado_sermon_series.ends_on, cayado_sermon_series.starts_on) >= ?", Date.new(year, 1, 1))
    }

    validates :title, presence: true
    validate :ends_after_start
    validate { must_belong_to_church(:move, move, church) }
    validate { must_belong_to_church(:owner_membership, owner_membership, church) }

    # How many week × ministry slots have a plan, out of all of them.
    def alignment
      total = weeks.size * church.ministries.size
      planned = AlignmentPlan.where(sermon_week_id: weeks.map(&:id)).count
      { planned: planned, total: total }
    end

    private

    def ends_after_start
      return if starts_on.nil? || ends_on.nil? || ends_on >= starts_on

      errors.add(:ends_on, "must be on or after the start date")
    end
  end
end
