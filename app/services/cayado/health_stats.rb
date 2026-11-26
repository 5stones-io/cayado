module Cayado
  # The Dashboard's arithmetic over WeeklyMetric and Budget, shared with
  # Congregation's headline numbers and This Week's "Last Sunday" card.
  # Everything is relative to the church's own today.
  class HealthStats
    # Average attendance compares this many weeks with the same span before.
    QUARTER_WEEKS = 13
    TRAILING_WEEKS = 52
    TREND_WEEKS = 5
    # Last Sunday is compared with the average of the Sundays before it.
    LAST_SUNDAY_BASELINE = 4
    MONTHS = 12

    attr_reader :church, :today

    def initialize(church, today: church.today)
      @church = church
      @today = today
    end

    # The latest Sunday on or before today: where the charts end.
    def as_of = @as_of ||= today - today.wday

    def stats
      {
        avg_attendance: avg_attendance,
        attendance_trend_pct: attendance_trend_pct,
        ytd_giving_cents: ytd_giving_cents,
        giving_through: giving_months.max&.strftime("%Y-%m"),
        months_reported: giving_months.size,
        giving_vs_budget_pct: giving_vs_budget_pct,
      }.merge(first_time_guests)
    end

    def avg_attendance = average(quarter(0))&.round

    def attendance_trend_pct
      now = average(quarter(0))
      before = average(quarter(1))
      return nil if now.nil? || before.nil? || before.zero?

      ((now - before) / before * 100).round(1)
    end

    # This month's first-time guests, and the difference from the average
    # of the three months before (nil when those months have no counts).
    def first_time_guests
      this_month = metrics_in(today.beginning_of_month..today).sum { _1.first_time_guests.to_i }
      before = (1..3).map { today.beginning_of_month << _1 }
      counted = metrics_in(before.last..(today.beginning_of_month - 1)).reject { _1.first_time_guests.nil? }
      vs = counted.empty? ? nil : this_month - (counted.sum(&:first_time_guests) / 3.0).round
      { first_time_guests_this_month: this_month, first_time_guests_vs_3mo: vs }
    end

    # 52 Sundays ending at as_of. Missing weeks are nulls so the x-axis stays
    # even; trend is the average of the counted weeks among the last five.
    def weekly
      (0...TRAILING_WEEKS).map do |i|
        week_of = as_of - (TRAILING_WEEKS - 1 - i).weeks
        metric = by_week[week_of]
        trend = average((0...TREND_WEEKS).filter_map { by_week[week_of - _1.weeks] })&.round
        { week_of: week_of, attendance: metric&.attendance, trend: metric&.attendance && trend, label: metric&.label }
      end
    end

    # Twelve months ending this one. The current month is partial, so it
    # isn't judged against the budget yet.
    def monthly_giving
      (0...MONTHS).map do |i|
        month = today.beginning_of_month << (MONTHS - 1 - i)
        giving = month_giving(month)
        budget = budget_for(month.year)&.monthly_cents
        partial = month == today.beginning_of_month
        status = if partial || giving.nil? || budget.nil? then nil
                 elsif giving >= budget then "at_or_above"
                 else "below"
                 end
        { month: month.strftime("%Y-%m"), giving_cents: giving, budget_cents: budget, status: status, partial: partial }
      end
    end

    # The most recent weekend that has a by-ministry split.
    def by_ministry
      metric = metrics.reverse.find { _1.by_ministry.present? }
      metric && { week_of: metric.week_of, rows: metric.by_ministry }
    end

    def budget = budget_for(today.year)

    # This Week's card: the Sunday before today (before the one This Week is
    # about), or nil until its numbers are in.
    def last_sunday
      date = today - (today.sunday? ? 7 : today.wday)
      metric = by_week[date]
      return nil unless metric

      baseline = average((1..LAST_SUNDAY_BASELINE).filter_map { by_week[date - _1.weeks] })
      weekly_budget = budget_for(date.year)&.weekly_cents
      {
        week_of: date,
        attendance: metric.attendance,
        attendance_vs_avg: metric.attendance && baseline && (metric.attendance - baseline).round,
        first_time_guests: metric.first_time_guests,
        giving_cents: metric.giving_cents,
        giving_budget_cents: weekly_budget,
        giving_vs_budget_pct: metric.giving_cents && weekly_budget &&
          ((metric.giving_cents * 100r / weekly_budget) - 100).round,
      }
    end

    private

    # Enough history for every figure above: 52 weeks plus the trend and
    # last-Sunday baselines, and back to the first of the oldest month shown.
    def metrics
      @metrics ||= begin
        from = [as_of - (TRAILING_WEEKS + TREND_WEEKS).weeks, today.beginning_of_month << MONTHS].min
        church.weekly_metrics.between(from..today).to_a
      end
    end

    def by_week = @by_week ||= metrics.index_by(&:week_of)

    def metrics_in(range) = metrics.select { range.cover?(_1.week_of) }

    # Attendance over the counted weeks of `rows`.
    def average(rows)
      counts = rows.filter_map(&:attendance)
      counts.empty? ? nil : counts.sum.to_f / counts.size
    end

    # The nth 13-week block back from as_of (0 = the latest).
    def quarter(n)
      ends = as_of - (n * QUARTER_WEEKS).weeks
      metrics_in((ends - (QUARTER_WEEKS - 1).weeks)..ends)
    end

    def month_giving(month)
      rows = metrics_in(month..month.end_of_month).reject { _1.giving_cents.nil? }
      rows.empty? ? nil : rows.sum(&:giving_cents)
    end

    def ytd_giving_cents = metrics_in(today.beginning_of_year..today).sum { _1.giving_cents.to_i }

    # First days of this year's months that have any giving counted.
    def giving_months
      @giving_months ||= (1..today.month).map { Date.new(today.year, _1, 1) }.select { month_giving(_1) }
    end

    # Finished months only: a month in progress always looks short.
    # Rationals, so 102.5% rounds to 103 rather than float's 102.4999…
    def giving_vs_budget_pct
      monthly = budget&.monthly_cents
      done = giving_months.select { _1 < today.beginning_of_month }
      return nil if monthly.nil? || done.empty?

      (done.sum { month_giving(_1) } * 100r / (monthly * done.size)).round
    end

    def budget_for(year)
      @budgets ||= church.budgets.index_by(&:year)
      @budgets[year]
    end
  end
end
