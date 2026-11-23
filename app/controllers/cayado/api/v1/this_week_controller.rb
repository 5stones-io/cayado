module Cayado
  module Api
    module V1
      # GET /api/v1/this_week: the home screen (web This Week, mobile home).
      # The Sunday ahead and its alignment slots, the next two weeks, which
      # pillar the coming month advances, and what needs the pastor's eye.
      # Last Sunday's numbers and the congregation snapshot pinned to the
      # week ahead, when there are any.
      class ThisWeekController < BaseController
        include Cayado::PlanningJson
        include Cayado::HealthJson

        # How many Sundays (from the one ahead) the vision pulse and the
        # attention list look at.
        LOOKAHEAD_WEEKS = 4
        COMING_UP = 2
        # Plans are due the Thursday before the Sunday.
        DUE_DAYS_BEFORE = 3

        def show
          today = Current.church.today
          ahead = SermonWeek.for_church(Current.church).where(preached_on: today..).order(:preached_on, :id)
                            .includes(:alignment_plans, sermon_series: [:weeks, { move: :pillar }])
                            .limit(LOOKAHEAD_WEEKS + COMING_UP).to_a
          week = ahead.first
          window = week ? ahead.select { _1.preached_on < week.preached_on + LOOKAHEAD_WEEKS.weeks } : []

          render json: {
            today: today,
            week: week && this_week_json(week),
            my_slots: week ? my_ministries.map(&:key) : [],
            coming_up: ahead.drop(1).first(COMING_UP).map { coming_up_json(_1) },
            vision_pulse: vision_pulse(window),
            attention: attention(window),
            last_sunday: HealthStats.new(Current.church, today: today).last_sunday,
            congregation_note: week && snapshot_json(week.congregation_snapshot, pinned: false),
          }
        end

        private

        def this_week_json(week)
          series = week.sermon_series
          planned = week.alignment_plans.map(&:ministry_id) & ministries.map(&:id)
          week_json(week, ministries: ministries).merge(
            weeks_count: series.weeks.size,
            due_on: week.preached_on - DUE_DAYS_BEFORE,
            series: { id: series.id, title: series.title },
            ready: planned.size,
            total: ministries.size
          )
        end

        def coming_up_json(week)
          series = week.sermon_series
          { id: week.id, position: week.position, title: week.title, scripture: week.scripture,
            preached_on: week.preached_on, series: { id: series.id, title: series.title },
            my_status: my_status(week) }
        end

        # nil for someone who leads no ministry; otherwise whether every
        # ministry they lead has a plan for the week.
        def my_status(week)
          return nil if my_ministries.empty?

          planned = week.alignment_plans.map(&:ministry_id)
          (my_ministries.map(&:id) - planned).empty? ? "planned" : "needs_plan"
        end

        def my_ministries
          @my_ministries ||= ministries.select { _1.lead_membership_id == Current.membership.id }
        end

        # The pillar most of the coming weeks' series advance.
        def vision_pulse(weeks)
          pillars = weeks.filter_map { _1.sermon_series.move&.pillar }
          return nil if pillars.empty?

          pillar, count = pillars.tally.max_by { |p, n| [n, -pillars.index(p)] }
          { pillar: { id: pillar.id, title: pillar.title, tone: pillar.tone },
            weeks_advancing: count, of: weeks.size }
        end

        def attention(weeks)
          no_scripture = weeks.select { _1.scripture.blank? }.map do |week|
            { kind: "needs_scripture",
              text: "#{week.sermon_series.title} Week #{week.position} needs a scripture anchor",
              sermon_week_id: week.id, ministry_key: nil }
          end
          no_lead = ministries.select { _1.lead_membership_id.nil? }.map do |ministry|
            { kind: "needs_lead", text: "#{ministry.name} has no lead to plan its slot",
              sermon_week_id: nil, ministry_key: ministry.key }
          end
          no_scripture + no_lead
        end
      end
    end
  end
end
