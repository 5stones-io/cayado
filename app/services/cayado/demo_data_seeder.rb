module Cayado
  # Fills a church with Lovable's demo church, Jubilee Christian Center
  # (data in DemoDataSeeder::Jubilee): staff, vision, the year's sermon
  # series and roadmap, topics, a year of Sunday numbers and a congregation
  # snapshot. For a demo tenant and for local development.
  #
  # Lovable's mockup was all 2026. Here the calendar follows the year it's
  # seeded in (Rooted on February's second Sunday, Unshakable two weeks after
  # Easter, Light of the World from Advent Sunday, …), which gives Lovable's
  # exact dates in 2026. The vision stays 2026–2030, since its words name
  # those years. Sunday numbers run back a year from today, so the
  # Dashboard is full whenever it's seeded.
  #
  # Only for a church with no planning data yet: AlreadySeeded otherwise.
  class DemoDataSeeder
    class AlreadySeeded < StandardError; end

    D = Jubilee
    # A year of Sundays plus the 5-week trend and Last Sunday baselines.
    METRIC_WEEKS = 60

    # Creates the church if there's none with `slug`, seeds it, and makes
    # `owner_email` (if given) an owner so a real person can sign in to it.
    def self.seed_church!(slug: "jubilee", name: "Jubilee Christian Center", owner_email: nil)
      church = Church.find_or_create_by!(slug: slug) do |c|
        c.assign_attributes(name: name, status: "approved", timezone: D::TIMEZONE)
      end
      new(church).call
      if owner_email.present?
        account = Account.find_or_create_by!(email: owner_email.strip.downcase)
        church.memberships.find_or_initialize_by(account: account).update!(role: "owner")
      end
      church
    end

    def initialize(church, today: church.today)
      @church = church
      @today = today
      @year = today.year
    end

    def call
      raise AlreadySeeded, "#{@church.slug} already has a vision" if @church.vision

      ApplicationRecord.transaction do
        @church.update!(city: @church.city.presence || D::CITY, state: @church.state.presence || D::STATE)
        seed_staff
        seed_vision
        seed_series
        seed_roadmap
        seed_attachments
        seed_topic_weights
        seed_metrics
        seed_snapshot
      end
      @church
    end

    private

    attr_reader :staff, :moves, :series

    def seed_staff
      @staff = D::STAFF.to_h do |initials, (first, last, title, role)|
        account = Account.find_or_create_by!(email: "#{first}.#{last}@#{D::EMAIL_DOMAIN}".downcase) do |a|
          a.assign_attributes(first_name: first, last_name: last)
        end
        [initials, @church.memberships.create!(account: account, title: title, role: role)]
      end
      @church.ministries.each do |ministry|
        lead = D::MINISTRY_LEADS[ministry.key]
        ministry.update!(lead_membership: staff[lead]) if lead
      end
    end

    def seed_vision
      vision = @church.create_vision!(D::VISION.merge(
        subtitle: "Where God is leading us — a five-year pastoral horizon for #{@church.brand_name}.",
      ))
      @pillars = {}
      @moves = {}
      D::PILLARS.each_with_index do |p, i|
        pillar = vision.pillars.create!(title: p[:title], tone: p[:tone], blurb: p[:blurb], position: i + 1)
        p[:editors].each { pillar.pillar_editors.create!(membership: staff[_1]) }
        p[:moves].each_with_index { |(key, text), j| moves[key] = pillar.moves.create!(text: text, position: j + 1) }
        @pillars[p[:title]] = pillar
      end
      D::YEARS.each { |year, (headline, goals)| vision.horizon_years.create!(year: year, headline: headline, goals: goals) }
    end

    def seed_series
      ministries = @church.ministries.index_by(&:key)
      @series = D::SERIES.to_h do |key, s|
        start = series_start(s[:starts])
        sermon_series = @church.sermon_series.create!(
          title: s[:title], theme: s[:theme], scripture: s[:scripture], move: moves[s[:move]],
          owner_membership: staff["DC"], starts_on: start, ends_on: start + (s[:weeks].size - 1).weeks,
        )
        s[:weeks].each_with_index do |(title, scripture, big_idea, plans, thread), i|
          week = sermon_series.weeks.create!(position: i + 1, preached_on: start + i.weeks,
                                             title: title, scripture: scripture, big_idea: big_idea)
          seed_plans(week, plans.to_h, ministries)
          seed_thread(week, thread.to_a)
        end
        [key, sermon_series]
      end
    end

    # Plans went in the Tuesday before their Sunday, by the ministry's lead.
    def seed_plans(week, plans, ministries)
      plans.each_with_index do |(key, body), i|
        at = at_church_time(week.preached_on - 5, 10 + i)
        plan = week.alignment_plans.create!(ministry: ministries.fetch(key), body: body,
                                            updated_by_membership: staff[D::MINISTRY_LEADS[key]],
                                            created_at: at, updated_at: at)
        backdate(ActivityEvent.plan_saved!(plan), at)
      end
    end

    # The thread ran the Tuesday before, an hour apart.
    def seed_thread(week, thread)
      thread.each_with_index do |(initials, body), i|
        at = at_church_time(week.preached_on - 5, 14 + i)
        comment = week.comments.create!(membership: staff[initials], body: body, created_at: at, updated_at: at)
        backdate(ActivityEvent.comment_added!(comment), at)
      end
    end

    def seed_roadmap
      @items = D::ROADMAP.to_h do |r|
        start = event_date(r[:on], @year)
        item = @church.roadmap_items.create!(
          title: r[:title], lane: r[:lane], color: r[:color], notes: r[:notes], owner_membership: staff[r[:owner]],
          starts_on: start, ends_on: r[:weeks] == 1 ? start : start + r[:weeks].weeks - 1,
          move: moves[r[:move]], pillar: @pillars[r[:pillar]],
        )
        [r[:title], item]
      end
    end

    def seed_attachments
      D::ATTACHMENTS.each do |on, docs|
        attachable = series[on] || @items.fetch(on)
        docs.each do |title, url, owner, hours_ago, tags|
          at = Time.current - hours_ago.hours
          attachable.attachments.create!(title: title, url: url, owner_membership: staff[owner], tags: tags,
                                         created_at: at, updated_at: at)
        end
      end
    end

    def seed_topic_weights
      topics = @church.topics.index_by(&:name)
      D::TOPIC_WEIGHTS.each do |key, weights|
        weights.each { |name, weight| series[key].series_topics.create!(topic: topics.fetch(name), weight: weight) }
      end
    end

    # Lovable's attendance curve (a slow climb with some wobble), its two
    # spike Sundays, and each month's giving shared across its Sundays.
    def seed_metrics
      as_of = @today - @today.wday
      spikes = D::SPIKES.flat_map do |label, (rule, attendance, guests)|
        [@year - 1, @year].map { [event_date(rule, _1), [label, attendance, guests]] }
      end.to_h

      rows = (0...METRIC_WEEKS).map do |n|
        week_of = as_of - (METRIC_WEEKS - 1 - n).weeks
        t = n - (METRIC_WEEKS - 52)
        attendance = (760 + (t * 2.4) + (Math.sin(t * 1.3) * 35) + (Math.cos(t * 0.6) * 22)).round
        guests = [7, 9, 11, 8, 10, 6, 12][n % 7]
        label, attendance, guests = spikes[week_of] if spikes[week_of]
        { church_id: @church.id, week_of: week_of, attendance: attendance, first_time_guests: guests,
          giving_cents: weekly_giving_cents(week_of), by_ministry: by_ministry(attendance), label: label,
          source: "manual", created_at: Time.current, updated_at: Time.current, }
      end
      WeeklyMetric.insert_all!(rows)
      [@year - 1, @year].each { @church.budgets.create!(year: _1, monthly_cents: D::MONTHLY_BUDGET * 100) }
    end

    # The month's giving split evenly across its Sundays, any odd cents on
    # the first, so every month adds up to Lovable's figure.
    def weekly_giving_cents(sunday)
      sundays = sundays_in(sunday.year, sunday.month)
      total = D::MONTHLY_GIVING[sunday.month - 1] * 100
      share = total / sundays.size
      sunday == sundays.first ? total - (share * (sundays.size - 1)) : share
    end

    def by_ministry(attendance)
      scale = attendance.to_f / D::IN_PERSON.values.sum
      D::IN_PERSON.map { |name, value| { "name" => name, "value" => (value * scale).round } } +
        [{ "name" => "Online", "value" => D::ONLINE }]
    end

    # Taken last Sunday, pinned to Rooted week 3 (as in Lovable) and to the
    # week This Week is about now.
    def seed_snapshot
      snapshot = @church.congregation_snapshots.create!(D::SNAPSHOT.merge(taken_on: @today - @today.wday))
      weeks = [series["rooted"].weeks.find_by!(position: 3), SermonWeek.upcoming_for(@church, on: @today)]
      weeks.compact.uniq.each { _1.update!(congregation_snapshot: snapshot) }
    end

    def series_start(rule)
      case rule
      when :two_weeks_after_easter then easter(@year) + 2.weeks
      else event_date(rule, @year)
      end
    end

    NTH = { "second" => 2, "third" => 3, "fourth" => 4 }.freeze

    # :easter, :advent_sunday, :christmas_eve, or :<nth>_sunday_of_<month>.
    def event_date(rule, year)
      case rule.to_s
      when "easter" then easter(year)
      when "advent_sunday" then advent_sunday(year)
      when "christmas_eve" then Date.new(year, 12, 24)
      when /\A(second|third|fourth)_sunday_of_(\w+)\z/
        sundays_in(year, Date::MONTHNAMES.index(::Regexp.last_match(2).capitalize))[NTH[::Regexp.last_match(1)] - 1]
      else raise ArgumentError, "no date rule #{rule}"
      end
    end

    def sundays_in(year, month)
      first = Date.new(year, month, 1)
      (first..first.end_of_month).select(&:sunday?)
    end

    # Four Sundays before Christmas: the last Sunday before the 25th, less three weeks.
    def advent_sunday(year)
      christmas = Date.new(year, 12, 25)
      christmas - (christmas.sunday? ? 7 : christmas.wday) - 3.weeks
    end

    # Western Easter (the anonymous Gregorian computus).
    def easter(year)
      a = year % 19
      b, c = year.divmod(100)
      d, e = b.divmod(4)
      g = ((8 * b) + 13) / 25
      h = ((19 * a) + b - d - g + 15) % 30
      i, k = c.divmod(4)
      l = (32 + (2 * e) + (2 * i) - h - k) % 7
      m = (a + (11 * h) + (19 * l)) / 433
      month = (h + l - (7 * m) + 90) / 25
      Date.new(year, month, (h + l - (7 * m) + (33 * month) + 19) % 32)
    end

    # Never later than now: seeded in January, Rooted's plans aren't written yet.
    def at_church_time(date, hour) = [@church.time_zone.local(date.year, date.month, date.day, hour), Time.current].min

    def backdate(record, at) = record.update_columns(created_at: at, updated_at: at)
  end
end
