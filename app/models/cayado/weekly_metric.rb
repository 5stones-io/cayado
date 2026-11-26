module Cayado
  # One Sunday's whole-church numbers. Typed in by an admin until Planning
  # Center fills them (source "pco"). Null means "not counted", not zero.
  class WeeklyMetric < ApplicationRecord
    include NamedNumbers

    SOURCES = %w[manual pco].freeze

    belongs_to :church

    validates :week_of, presence: true, uniqueness: { scope: :church_id }
    validates :attendance, :first_time_guests, :giving_cents,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :source, inclusion: { in: SOURCES }
    validates_named_numbers :by_ministry, name_key: "name", number_key: "value"
    validate { errors.add(:week_of, "must be a Sunday") if week_of && !week_of.sunday? }

    scope :between, ->(range) { where(week_of: range).order(:week_of) }
  end
end
