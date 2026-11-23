require "rails_helper"

# Jubilee Christian Center, Lovable's demo church
# (cayado-staff-planner/src/lib/cayado-data.ts), laid on the church's
# current year so This Week, the Roadmap and the Dashboard all have
# something to show whenever it's seeded.
# type: :request for the This Week check through the real endpoint.
RSpec.describe Cayado::DemoDataSeeder, type: :request do
  let(:church) { create(:church, slug: "jubilee", name: "Jubilee Christian Center") }
  # Monday, Nov 23 2026: the Sunday ahead is Advent 1 (Nov 29).
  let(:now) { Time.zone.parse("2026-11-23 09:00 America/Chicago") }

  around { |example| travel_to(now) { example.run } }

  def seed! = described_class.new(church).call
  def staff(name) = church.memberships.joins(:account).find_by!(accounts: { first_name: name.split.first, last_name: name.split.last })
  def series(title) = church.sermon_series.find_by!(title: title)

  it "seeds Lovable's six staff with their titles, and the ministry leads" do
    seed!

    people = church.memberships.includes(:account).map { [_1.account.name, _1.title, _1.role] }
    expect(people).to contain_exactly(
      ["David Chen", "Lead Pastor", "owner"],
      ["Marcus Reyes", "Executive Pastor", "admin"],
      ["Elena Park", "Worship Pastor", "member"],
      ["Sarah Whitfield", "Kids Pastor", "member"],
      ["Jordan Adebayo", "Youth Pastor", "member"],
      ["Linnea Hoffman", "Small Groups Director", "member"],
    )
    leads = church.ministries.map { [_1.key, _1.lead_membership.account.name] }
    expect(leads).to eq([["kids", "Sarah Whitfield"], ["youth", "Jordan Adebayo"],
                         ["small-groups", "Linnea Hoffman"], ["worship", "Elena Park"]])
    expect(Account.where("email LIKE '%@jubilee.example'").count).to eq(6)
  end

  it "seeds the vision: three pillars with their editors and moves, and the five-year ladder" do
    seed!

    vision = church.vision
    expect(vision).to have_attributes(title: "2026–2030 Vision", start_year: 2026, end_year: 2030)
    expect(vision.pillars.map { [_1.title, _1.tone, _1.moves.size] })
      .to eq([["Reach", "ink", 3], ["Disciple", "sage", 3], ["Send", "terracotta", 3]])
    expect(vision.pillars.second.editors.map { _1.account.name })
      .to contain_exactly("David Chen", "Linnea Hoffman", "Sarah Whitfield")
    expect(vision.horizon_years.map { [_1.year, _1.headline] }.first).to eq([2026, "Year of Foundations"])
    expect(vision.horizon_years.size).to eq(5)
  end

  it "lays the four series on this year's calendar, with Lovable's dates in 2026" do
    seed!

    dates = church.sermon_series.order(:starts_on).map { [_1.title, _1.starts_on, _1.ends_on, _1.weeks.size] }
    expect(dates).to eq([
      ["Rooted", Date.new(2026, 2, 8), Date.new(2026, 3, 15), 6],
      ["Unshakable", Date.new(2026, 4, 19), Date.new(2026, 5, 24), 6],
      ["Home", Date.new(2026, 8, 23), Date.new(2026, 9, 20), 5],
      ["Light of the World", Date.new(2026, 11, 29), Date.new(2026, 12, 20), 4],
    ])
    expect(series("Rooted").move.text).to start_with("Re-launch small groups")
    expect(series("Light of the World").move.text).to eq("Launch a marketplace leaders cohort")
  end

  it "seeds Rooted's weeks with Lovable's plans and the week 1 thread" do
    seed!

    rooted = series("Rooted")
    expect(rooted.alignment).to eq(planned: 13, total: 24)
    week1 = rooted.weeks.first
    expect(week1).to have_attributes(title: "The Supremacy of Christ", scripture: "Colossians 1:15–23")
    kids_plan = week1.alignment_plans.joins(:ministry).find_by!(cayado_ministries: { key: "kids" })
    expect(kids_plan.updated_by_membership).to eq(staff("Sarah Whitfield"))
    expect(week1.comments.map { [_1.membership.account.name, _1.body] }).to eq([
      ["Sarah Whitfield", "Should the kids memory verse be Col 1:16 or 1:17? I'd lean 1:17 for the holding-together image."],
      ["David Chen", "1:17 — yes. Let's align."],
    ])
    # The attention item Lovable shows on This Week.
    expect(series("Unshakable").weeks.first.scripture).to be_nil
  end

  it "puts the roadmap's events on real dates and links them to the vision" do
    seed!

    items = church.roadmap_items.index_by(&:title)
    expect(items.size).to eq(8)
    expect(items["Easter Sunday"]).to have_attributes(lane: "major_event", starts_on: Date.new(2026, 4, 5),
                                                      ends_on: Date.new(2026, 4, 5), color: "gold")
    expect(items["Easter Sunday"].move.text).to start_with("Quarterly community Sundays")
    expect(items["Summer Nights Outreach"]).to have_attributes(lane: "outreach", pillar: church.vision.pillars.first, move: nil)
    expect(items["Christmas Eve Services"].starts_on).to eq(Date.new(2026, 12, 24))
    expect(items["Kids & Youth Camps"].owner_membership).to eq(staff("Sarah Whitfield"))
  end

  it "attaches Lovable's docs to Rooted, Unshakable, Easter and Summer Nights" do
    seed!

    expect(series("Rooted").attachments.map(&:kind).tally).to eq("doc" => 3, "sheet" => 1, "slide" => 1)
    expect(church.roadmap_items.find_by!(title: "Easter Sunday").attachments.size).to eq(2)
    expect(Cayado::Attachment.where(church: church).count).to eq(9)
  end

  it "weights each series' topics as Lovable does" do
    seed!

    weights = series("Rooted").series_topics.includes(:topic).to_h { [_1.topic.name, _1.weight] }
    expect(weights).to eq("Identity in Christ" => 3, "Discipleship" => 3, "Prayer" => 2, "The Gospel" => 2, "Holy Spirit" => 1)
    expect(Cayado::SeriesTopic.joins(:sermon_series).where(cayado_sermon_series: { church_id: church.id }).count).to eq(16)
  end

  it "fills a year of Sundays up to today, so the Dashboard has every figure" do
    seed!

    health = Cayado::HealthStats.new(church)
    expect(health.weekly.map { _1[:attendance] }).to all(be_present)
    expect(health.weekly.filter_map { _1[:label] }).to contain_exactly("Easter", "Vision Sunday")
    expect(health.stats[:avg_attendance]).to be_between(800, 900)
    expect(health.stats[:attendance_trend_pct]).to be_positive
    # Lovable's Jan–Oct giving against its $117,000 monthly budget.
    expect(health.stats[:ytd_giving_cents]).to eq(119_900_000 + health.monthly_giving.last[:giving_cents])
    expect(health.stats[:giving_vs_budget_pct]).to eq(102)
    expect(health.stats[:first_time_guests_this_month]).to be_positive
    expect(health.by_ministry[:rows].map { _1["name"] }).to eq(%w[Adults Youth Kids Online])
    expect(health.last_sunday).to include(week_of: Date.new(2026, 11, 22))
  end

  it "pins a congregation snapshot to Rooted week 3 and to the week This Week is about" do
    seed!

    snapshot = church.congregation_snapshots.sole
    expect(snapshot).to have_attributes(households: 412)
    expect(snapshot.life_stages.first).to eq("label" => "Young families with kids", "pct" => 32)
    expect(snapshot.pinned_weeks.map { [_1.sermon_series.title, _1.position] })
      .to eq([["Rooted", 3], ["Light of the World", 1]])
  end

  it "records Rooted's plans and comments in the Activity feed, when they happened" do
    seed!

    events = church.activity_events.order(:created_at)
    expect(events.map(&:kind).tally).to eq("plan_saved" => 13, "comment_added" => 2)
    expect(events.last.created_at.to_date).to be < Date.new(2026, 3, 15)
  end

  it "makes This Week about Advent 1 the Monday before it" do
    seed!
    use_tenant_host!(church)

    get "/api/v1/this_week", headers: auth_headers(staff("David Chen").account)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["week"]).to include("preached_on" => "2026-11-29", "title" => "The Light Promised")
    expect(body["congregation_note"]).to be_present
    expect(body["last_sunday"]).to include("week_of" => "2026-11-22")
  end

  it "follows the calendar into another year: Easter, Advent and Rooted move with it" do
    travel_to(Time.zone.parse("2027-03-01 09:00 America/Chicago"))
    seed!

    expect(series("Rooted").starts_on).to eq(Date.new(2027, 2, 14))
    expect(series("Unshakable").starts_on).to eq(Date.new(2027, 4, 11))
    expect(series("Light of the World").starts_on).to eq(Date.new(2027, 11, 28))
    expect(church.roadmap_items.find_by!(title: "Easter Sunday").starts_on).to eq(Date.new(2027, 3, 28))
  end

  it "won't seed a church that already has a vision" do
    create(:vision, church: church)

    expect { seed! }.to raise_error(described_class::AlreadySeeded)
    expect(church.sermon_series).to be_empty
  end

  it "touches only the church it's given" do
    other = create(:church, slug: "other")

    seed!

    expect(other.memberships).to be_empty
    expect(other.weekly_metrics).to be_empty
    expect(other.sermon_series).to be_empty
  end

  describe ".seed_church!" do
    it "creates the church in Fairfax's time zone and makes the given email an owner" do
      seeded = described_class.seed_church!(slug: "demo", owner_email: " Chad@Example.com ")

      expect(seeded).to have_attributes(slug: "demo", name: "Jubilee Christian Center", status: "approved",
                                        timezone: "America/New_York", city: "Fairfax", state: "VA")
      owner = seeded.memberships.joins(:account).find_by!(accounts: { email: "chad@example.com" })
      expect(owner.role).to eq("owner")
      expect(seeded.sermon_series.size).to eq(4)
    end

    it "seeds an existing church with that slug" do
      church

      expect(described_class.seed_church!(slug: "jubilee")).to eq(church)
      expect(church.reload.vision).to be_present
    end
  end
end
