module Cayado
  # One rung of the five-year ladder.
  class HorizonYear < ApplicationRecord
    belongs_to :vision

    validates :year, presence: true, uniqueness: { scope: :vision_id }
  end
end
