module Cayado
  # The church's giving budget for a year, as one monthly figure.
  class Budget < ApplicationRecord
    belongs_to :church

    validates :year, presence: true, uniqueness: { scope: :church_id }
    validates :monthly_cents, numericality: { only_integer: true, greater_than: 0 }

    # A single Sunday's share: the year's budget over 52 weeks.
    def weekly_cents = (monthly_cents * 12 / 52.0).round
  end
end
