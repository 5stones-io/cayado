module Cayado
  module Api
    module V1
      # The mobile Activity tab: what the rest of the team did, newest
      # first. Anything after the membership's activity_seen_at is unread.
      class ActivityController < BaseController
        include Cayado::PlanningJson

        DEFAULT_LIMIT = 50
        MAX_LIMIT = 100

        def show
          membership = Current.membership
          visible = ActivityEvent.visible_to(membership)
          limit = params[:limit].to_i.clamp(1, MAX_LIMIT)
          limit = DEFAULT_LIMIT if params[:limit].blank?

          page = visible.includes(:sermon_series, :sermon_week, actor_membership: :account).order(id: :desc)
          page = page.where(id: ...params[:before].to_i) if params[:before].present?
          events = page.limit(limit + 1).to_a
          more = events.size > limit
          events = events.first(limit)

          unread = membership.activity_seen_at ? visible.where("cayado_activity_events.created_at > ?", membership.activity_seen_at) : visible
          render json: {
            events: events.map { event_json(_1, membership) },
            unread_count: unread.count,
            next_before: more ? events.last.id : nil,
          }
        end

        def seen
          Current.membership.update!(activity_seen_at: Time.current)
          head :no_content
        end

        private

        def event_json(event, membership)
          data = event.data
          week = event.sermon_week
          series = event.sermon_series
          {
            id: event.id,
            kind: event.kind,
            actor: person_json(event.actor_membership),
            excerpt: data["subject"] || data["excerpt"],
            ministry: data["ministry_key"] && { key: data["ministry_key"], name: data["ministry_name"] },
            sermon_week: week && { id: week.id, position: week.position, title: week.title },
            sermon_series: series && { id: series.id, title: series.title },
            unread: event.unread_for?(membership),
            created_at: event.created_at,
          }
        end
      end
    end
  end
end
