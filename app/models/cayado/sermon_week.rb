module Cayado
  class SermonWeek < ApplicationRecord
    belongs_to :sermon_series, class_name: "Cayado::SermonSeries"
    has_many :alignment_plans, dependent: :destroy
    has_many :comments, -> { order(:created_at, :id) }, dependent: :destroy, inverse_of: :sermon_week

    validates :preached_on, presence: true

    delegate :church, to: :sermon_series

    scope :for_church, ->(church) { joins(:sermon_series).where(cayado_sermon_series: { church_id: church.id }) }

    # The week preached on the next Sunday on or after `on` (that Sunday
    # itself, if it's one): what "This Week" is about.
    def self.upcoming_for(church, on: church.today)
      for_church(church).where(preached_on: on..).order(:preached_on, :id).first
    end
  end
end
