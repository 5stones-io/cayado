module Cayado
  # A subject in the church's teaching library ("Prayer", "Generosity").
  # Series carry topics with a weight; the Topics screen maps them by month.
  class Topic < ApplicationRecord
    DEFAULTS = [
      "Identity in Christ", "Prayer", "Discipleship", "Community", "Generosity", "Justice & Mercy",
      "Suffering & Hope", "Mission & Evangelism", "Family & Marriage", "Holy Spirit", "Worship", "The Gospel",
    ].freeze

    belongs_to :church
    has_many :series_topics, dependent: :delete_all

    validates :name, presence: true, uniqueness: { scope: :church_id }

    def self.create_defaults!(church)
      DEFAULTS.each_with_index do |name, i|
        church.topics.find_or_create_by!(name: name) { _1.position = i }
      end
    end
  end
end
