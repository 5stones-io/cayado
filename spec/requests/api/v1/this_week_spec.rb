require "rails_helper"

RSpec.describe "GET /api/v1/this_week", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:sarah) { create(:membership, church: church, title: "Kids Pastor", account: create(:account, first_name: "Sarah", last_name: "Whitfield")) }
  let(:elena) { create(:membership, church: church, title: "Worship Pastor") }
  let(:kids) { church.ministries.find_by!(key: "kids") }
  let(:worship) { church.ministries.find_by!(key: "worship") }
  let(:youth) { church.ministries.find_by!(key: "youth") }
  let(:groups) { church.ministries.find_by!(key: "small-groups") }
  let(:vision) { create(:vision, church: church) }
  let(:disciple) { create(:pillar, vision: vision, title: "Disciple", tone: "sage") }
  let(:reach) { create(:pillar, vision: vision, title: "Reach", tone: "terracotta") }
  let(:rooted) { create(:sermon_series, church: church, title: "Rooted", move: create(:move, pillar: disciple)) }

  # Monday, Feb 23 2026: the Sunday ahead is Mar 1.
  let(:monday) { Time.zone.parse("2026-02-23 09:00 America/Chicago") }

  before do
    kids.update!(lead_membership: sarah)
    worship.update!(lead_membership: elena)
    use_tenant_host!(church)
  end

  around { |example| travel_to(monday) { example.run } }

  it "is about the Sunday ahead: the week, its slots and how many are ready" do
    create(:sermon_week, sermon_series: rooted, position: 2, preached_on: Date.new(2026, 2, 22))
    week = create(:sermon_week, sermon_series: rooted, position: 3, preached_on: Date.new(2026, 3, 1),
                                title: "Free in Christ", scripture: "Colossians 2:13–15", big_idea: "Nailed to the cross.")
    create(:sermon_week, sermon_series: rooted, position: 4, preached_on: Date.new(2026, 3, 8))
    create(:alignment_plan, sermon_week: week, ministry: worship, body: "Living Hope")
    create(:alignment_plan, sermon_week: week, ministry: youth, body: "Testimony night")

    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(response).to have_http_status(:ok)
    expect(json["today"]).to eq("2026-02-23")
    expect(json["week"]).to include(
      "id" => week.id, "position" => 3, "weeks_count" => 3, "title" => "Free in Christ",
      "scripture" => "Colossians 2:13–15", "big_idea" => "Nailed to the cross.",
      "preached_on" => "2026-03-01", "due_on" => "2026-02-26",
      "series" => { "id" => rooted.id, "title" => "Rooted" },
      "ready" => 2, "total" => 4
    )
    expect(json.dig("week", "slots").map { _1.dig("ministry", "key") }).to eq(%w[kids youth small-groups worship])
    expect(json["my_slots"]).to eq([])
  end

  it "puts the signed-in lead's own slot first in my_slots" do
    week = create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 1))

    get "/api/v1/this_week", headers: auth_headers(sarah.account)

    expect(json["my_slots"]).to eq(["kids"])
    expect(json.dig("week", "id")).to eq(week.id)
  end

  it "lists the next two weeks with whether the lead still owes a plan" do
    create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 1))
    w4 = create(:sermon_week, sermon_series: rooted, position: 4, preached_on: Date.new(2026, 3, 8), title: "Set Your Mind")
    w5 = create(:sermon_week, sermon_series: rooted, position: 5, preached_on: Date.new(2026, 3, 15), title: "The New Self")
    create(:sermon_week, sermon_series: rooted, position: 6, preached_on: Date.new(2026, 3, 22))
    create(:alignment_plan, sermon_week: w5, ministry: kids)

    get "/api/v1/this_week", headers: auth_headers(sarah.account)

    expect(json["coming_up"].map { _1.slice("id", "position", "title", "my_status") }).to eq([
      { "id" => w4.id, "position" => 4, "title" => "Set Your Mind", "my_status" => "needs_plan" },
      { "id" => w5.id, "position" => 5, "title" => "The New Self", "my_status" => "planned" },
    ])
    expect(json["coming_up"].first["series"]).to eq("id" => rooted.id, "title" => "Rooted")
  end

  it "has no my_status for someone who leads nothing" do
    create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 1))
    create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 8))

    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(json["coming_up"].sole["my_status"]).to be_nil
  end

  it "names the pillar most of the next four weeks advance" do
    unshakable = create(:sermon_series, church: church, title: "Unshakable", move: create(:move, pillar: reach))
    3.times { |i| create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 1) + i.weeks) }
    create(:sermon_week, sermon_series: unshakable, preached_on: Date.new(2026, 3, 22))
    create(:sermon_week, sermon_series: unshakable, preached_on: Date.new(2026, 3, 29))

    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(json["vision_pulse"]).to eq(
      "pillar" => { "id" => disciple.id, "title" => "Disciple", "tone" => "sage" },
      "weeks_advancing" => 3, "of" => 4
    )
  end

  it "flags upcoming weeks with no scripture and ministries with no lead" do
    unshakable = create(:sermon_series, church: church, title: "Unshakable")
    create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 1), scripture: "Col 2:13")
    gap = create(:sermon_week, sermon_series: unshakable, position: 1, preached_on: Date.new(2026, 3, 8), scripture: nil)
    create(:sermon_week, sermon_series: unshakable, position: 9, preached_on: Date.new(2026, 6, 1), scripture: nil)

    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(json["attention"]).to eq([
      { "kind" => "needs_scripture", "text" => "Unshakable Week 1 needs a scripture anchor",
        "sermon_week_id" => gap.id, "ministry_key" => nil },
      { "kind" => "needs_lead", "text" => "Youth has no lead to plan its slot",
        "sermon_week_id" => nil, "ministry_key" => "youth" },
      { "kind" => "needs_lead", "text" => "Small Groups has no lead to plan its slot",
        "sermon_week_id" => nil, "ministry_key" => "small-groups" },
    ])
  end

  it "leaves the health cards empty until Planning Center numbers exist" do
    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(json).to include("last_sunday" => nil, "congregation_note" => nil)
  end

  it "has no week, pulse or coming-up when nothing is planned ahead" do
    create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 2, 15))

    get "/api/v1/this_week", headers: auth_headers(sarah.account)

    expect(response).to have_http_status(:ok)
    expect(json).to include("week" => nil, "my_slots" => [], "coming_up" => [], "vision_pulse" => nil)
  end

  it "uses the church's own date, not the server's" do
    church.update!(timezone: "Pacific/Honolulu")
    week = create(:sermon_week, sermon_series: rooted, preached_on: Date.new(2026, 3, 1))

    # Sunday 11pm in Honolulu is already Monday in UTC; Mar 1 is still "this" Sunday.
    travel_back
    travel_to(Time.find_zone("Pacific/Honolulu").parse("2026-03-01 23:00"))
    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(json["today"]).to eq("2026-03-01")
    expect(json.dig("week", "id")).to eq(week.id)
  end

  it "doesn't show another church's weeks" do
    other = create(:sermon_series, church: create(:church))
    create(:sermon_week, sermon_series: other, preached_on: Date.new(2026, 3, 1))

    get "/api/v1/this_week", headers: auth_headers(pastor.account)

    expect(json["week"]).to be_nil
  end
end
