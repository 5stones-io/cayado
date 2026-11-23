module Cayado
  # Something a teammate did that the rest of the staff should hear about
  # (the mobile Activity tab). Recorded by the controllers after the change
  # saves; never edited afterwards.
  class ActivityEvent < ApplicationRecord
    KINDS = %w[comment_added plan_saved team_notified].freeze
    EXCERPT_LENGTH = 140

    belongs_to :church
    belongs_to :actor_membership, class_name: "::Membership", optional: true
    belongs_to :sermon_series, class_name: "Cayado::SermonSeries", optional: true
    belongs_to :sermon_week, class_name: "Cayado::SermonWeek", optional: true

    validates :kind, inclusion: { in: KINDS }

    # What `membership` sees: everyone else's activity at their church, and
    # heads-ups only when they were one of the people told.
    scope :visible_to, lambda { |membership|
      where(church_id: membership.church_id)
        .where("actor_membership_id IS NULL OR actor_membership_id <> ?", membership.id)
        .where("kind <> 'team_notified' OR data->'recipient_ids' @> ?", [membership.id].to_json)
    }

    def self.excerpt(text)
      text.to_s.squish.truncate(EXCERPT_LENGTH, separator: " ")
    end

    def self.comment_added!(comment)
      week = comment.sermon_week
      create!(church: week.church, actor_membership: comment.membership, kind: "comment_added",
              sermon_week: week, sermon_series: week.sermon_series, data: { excerpt: excerpt(comment.body) })
    end

    def self.plan_saved!(plan)
      week = plan.sermon_week
      ministry = plan.ministry
      create!(church: week.church, actor_membership: plan.updated_by_membership, kind: "plan_saved",
              sermon_week: week, sermon_series: week.sermon_series,
              data: { ministry_key: ministry.key, ministry_name: ministry.name, excerpt: excerpt(plan.body) })
    end

    def unread_for?(membership)
      membership.activity_seen_at.nil? || created_at > membership.activity_seen_at
    end
  end
end
