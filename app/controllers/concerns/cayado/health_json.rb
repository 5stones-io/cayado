module Cayado
  # JSON shapes for the health aggregates (Dashboard, Congregation, This Week).
  module HealthJson
    private

    def weekly_metric_json(metric)
      metric.slice(:week_of, :attendance, :first_time_guests, :giving_cents, :by_ministry, :label, :source)
    end

    def budget_json(budget) = budget && { year: budget.year, monthly_cents: budget.monthly_cents }

    # pinned: false for where the week is already known (This Week's note).
    def snapshot_json(snapshot, pinned: true)
      return nil unless snapshot

      json = snapshot.slice(:id, :taken_on, :households, :life_stages, :season_markers, :note)
      return json unless pinned

      json.merge(pinned_weeks: snapshot.pinned_weeks.includes(:sermon_series).map do |week|
        { id: week.id, position: week.position, title: week.title, preached_on: week.preached_on,
          series: { id: week.sermon_series.id, title: week.sermon_series.title } }
      end)
    end
  end
end
