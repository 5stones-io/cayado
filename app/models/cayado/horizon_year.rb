module Cayado
  # One rung of the five-year ladder.
  class HorizonYear < ApplicationRecord
    belongs_to :vision

    validates :year, presence: true, uniqueness: { scope: :vision_id }
    validate :within_vision

    private

    def within_vision
      return if year.nil? || vision.nil? || year.between?(vision.start_year, vision.end_year)

      errors.add(:year, "must be between #{vision.start_year} and #{vision.end_year}")
    end
  end
end
