require "rails_helper"

RSpec.describe "GET /api/v1/vision", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:linnea) { create(:membership, church: church, title: "Small Groups Director", account: create(:account, first_name: "Linnea", last_name: "Hoffman")) }

  before { use_tenant_host!(church) }

  it "gives the pillars in order with their moves, editors and the series advancing each move, then the year ladder" do
    vision = create(:vision, church: church, title: "2026–2030 Vision", subtitle: "Reach, disciple, send")
    send_pillar = create(:pillar, vision: vision, position: 2, title: "Send", tone: "terracotta")
    disciple = create(:pillar, vision: vision, position: 1, title: "Disciple", tone: "sage", blurb: "Ordinary disciples")
    rooted_move = create(:move, pillar: disciple, position: 1, text: "Re-launch small groups")
    Cayado::PillarEditor.create!(pillar: disciple, membership: linnea)
    rooted = create(:sermon_series, church: church, title: "Rooted", move: rooted_move)
    create(:horizon_year, vision: vision, year: 2027, headline: "Year of Multiplication", goals: ["Open Reston"])
    create(:horizon_year, vision: vision, year: 2026, headline: "Year of Foundations", goals: ["Launch Rooted", "Hire"])

    get "/api/v1/vision", headers: auth_headers(linnea.account)

    expect(response).to have_http_status(:ok)
    expect(json).to include("title" => "2026–2030 Vision", "subtitle" => "Reach, disciple, send", "start_year" => 2026, "end_year" => 2030)
    expect(json["pillars"].map { _1["title"] }).to eq(%w[Disciple Send])
    expect(json["pillars"].first).to eq(
      "id" => disciple.id, "title" => "Disciple", "blurb" => "Ordinary disciples", "tone" => "sage", "can_edit" => true,
      "editors" => [{ "membership_id" => linnea.id, "name" => "Linnea Hoffman", "title" => "Small Groups Director", "initials" => "LH" }],
      "moves" => [{ "id" => rooted_move.id, "text" => "Re-launch small groups",
                    "sermon_series" => [{ "id" => rooted.id, "title" => "Rooted" }] }]
    )
    expect(json["pillars"].second).to include("id" => send_pillar.id, "can_edit" => false)
    expect(json["years"]).to eq([
      { "year" => 2026, "headline" => "Year of Foundations", "goals" => ["Launch Rooted", "Hire"] },
      { "year" => 2027, "headline" => "Year of Multiplication", "goals" => ["Open Reston"] },
    ])
  end

  it "lets an admin edit every pillar" do
    create(:pillar, vision: create(:vision, church: church))

    get "/api/v1/vision", headers: auth_headers(pastor.account)

    expect(json["pillars"].sole["can_edit"]).to be(true)
  end

  it "is null until the church has written its vision" do
    get "/api/v1/vision", headers: auth_headers(linnea.account)

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("null")
  end
end
