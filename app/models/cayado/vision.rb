module Cayado
  class Vision < ApplicationRecord
    belongs_to :church
    has_many :pillars, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :vision
    has_many :horizon_years, -> { order(:year) }, dependent: :destroy, inverse_of: :vision

    validates :title, presence: true
    validates :church_id, uniqueness: true
    validates :start_year, :end_year, presence: true, numericality: { only_integer: true }
    validate :years_run_forward

    private

    def years_run_forward
      return if start_year.nil? || end_year.nil? || end_year >= start_year

      errors.add(:end_year, "must be on or after the start year")
    end
  end
end
