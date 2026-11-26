require "rails_helper"

RSpec.describe "Sermon series API", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, title: "Lead Pastor", account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:sarah) { create(:membership, church: church, title: "Kids Pastor", account: create(:account, first_name: "Sarah", last_name: "Whitfield")) }
  let(:kids) { church.ministries.find_by!(key: "kids") }
  let(:youth) { church.ministries.find_by!(key: "youth") }

  let(:vision) { create(:vision, church: church) }
  let(:disciple) { create(:pillar, vision: vision, title: "Disciple", tone: "sage") }
  let(:move) { create(:move, pillar: disciple, text: "Re-launch small groups around Rooted") }

  let!(:rooted) do
    create(:sermon_series, church: church, title: "Rooted", theme: "A study of Colossians", scripture: "Colossians 1–4",
                           starts_on: Date.new(2026, 2, 8), ends_on: Date.new(2026, 3, 15), owner_membership: pastor, move: move)
  end
  let!(:week1) do
    create(:sermon_week, sermon_series: rooted, position: 1, preached_on: Date.new(2026, 2, 8), title: "The Supremacy of Christ",
                         scripture: "Colossians 1:15–23", big_idea: "Christ holds it together.")
  end

  before do
    kids.update!(lead_membership: sarah)
    use_tenant_host!(church)
  end

  def person(membership, name, title)
    { "membership_id" => membership.id, "name" => name, "title" => title, "initials" => name.split.map { _1[0] }.join }
  end

  describe "GET /api/v1/sermon_series" do
    it "lists the church's series in date order with who owns them, what they advance and how aligned they are" do
      create(:sermon_series, church: church, title: "Light", starts_on: Date.new(2026, 11, 29), ends_on: Date.new(2026, 12, 20))
      create(:sermon_series, title: "Another church's series")
      create(:alignment_plan, sermon_week: week1, ministry: kids, body: "Creation story")

      get "/api/v1/sermon_series", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json["series"].map { _1["title"] }).to eq(%w[Rooted Light])
      expect(json["series"].first).to eq(
        "id" => rooted.id, "title" => "Rooted", "theme" => "A study of Colossians", "scripture" => "Colossians 1–4",
        "starts_on" => "2026-02-08", "ends_on" => "2026-03-15",
        "owner" => person(pastor, "David Chen", "Lead Pastor"),
        "advances" => { "pillar" => { "id" => disciple.id, "title" => "Disciple", "tone" => "sage" },
                        "move" => { "id" => move.id, "text" => "Re-launch small groups around Rooted" } },
        "weeks_count" => 1, "alignment" => { "planned" => 1, "total" => 4 }
      )
    end

    it "needs a full sign-in" do
      get "/api/v1/sermon_series"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/sermon_series/:id" do
    it "gives each week with a slot for every ministry, planned or awaiting" do
      create(:alignment_plan, sermon_week: week1, ministry: kids, body: "Creation story", memory_verse: "Col 1:17",
                              updated_by_membership: sarah)
      create(:comment, sermon_week: week1, membership: sarah)

      get "/api/v1/sermon_series/#{rooted.id}", headers: auth_headers(sarah.account)

      week = json["weeks"].sole
      expect(week).to include("id" => week1.id, "position" => 1, "preached_on" => "2026-02-08",
                              "title" => "The Supremacy of Christ", "scripture" => "Colossians 1:15–23",
                              "big_idea" => "Christ holds it together.", "comments_count" => 1)
      expect(week["slots"].map { _1.dig("ministry", "key") }).to eq(%w[kids youth small-groups worship])
      expect(week["slots"].first).to include(
        "ministry" => { "key" => "kids", "name" => "Kids", "color" => kids.color },
        "lead" => person(sarah, "Sarah Whitfield", "Kids Pastor"),
        "can_edit" => true
      )
      expect(week["slots"].first["plan"]).to include("body" => "Creation story", "memory_verse" => "Col 1:17",
                                                     "updated_by" => person(sarah, "Sarah Whitfield", "Kids Pastor"))
      expect(week["slots"].second).to include("plan" => nil, "lead" => nil, "can_edit" => false)
    end

    it "is a 404 for another church's series" do
      other = create(:sermon_series)

      get "/api/v1/sermon_series/#{other.id}", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:not_found)
      expect(json["code"]).to eq("not_found")
    end
  end

  describe "writing series and weeks" do
    it "lets an admin create a series and add weeks to it" do
      post "/api/v1/sermon_series", headers: auth_headers(pastor.account),
                                    params: { title: "Home", theme: "What family was meant to be", starts_on: "2026-08-23",
                                              ends_on: "2026-09-20", owner_membership_id: pastor.id, move_id: move.id }
      expect(response).to have_http_status(:created)
      series = Cayado::SermonSeries.find(json["id"])
      expect(series).to have_attributes(church: church, title: "Home", move: move, owner_membership: pastor)

      post "/api/v1/sermon_series/#{series.id}/weeks", headers: auth_headers(pastor.account),
                                                       params: { preached_on: "2026-08-23", title: "Made for Belonging" }
      expect(response).to have_http_status(:created)
      expect(series.weeks.sole).to have_attributes(position: 1, title: "Made for Belonging")
    end

    it "lets an admin edit and delete a series and a week" do
      patch "/api/v1/sermon_series/#{rooted.id}", headers: auth_headers(pastor.account), params: { title: "Rooted (Colossians)" }
      expect(rooted.reload.title).to eq("Rooted (Colossians)")

      patch "/api/v1/sermon_weeks/#{week1.id}", headers: auth_headers(pastor.account), params: { big_idea: "New idea" }
      expect(week1.reload.big_idea).to eq("New idea")

      delete "/api/v1/sermon_weeks/#{week1.id}", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)

      delete "/api/v1/sermon_series/#{rooted.id}", headers: auth_headers(pastor.account)
      expect(Cayado::SermonSeries.exists?(rooted.id)).to be(false)
    end

    it "explains what's wrong with a bad series" do
      post "/api/v1/sermon_series", headers: auth_headers(pastor.account), params: { title: "" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("title")
    end

    it "won't link a series to another church's move or staff" do
      post "/api/v1/sermon_series", headers: auth_headers(pastor.account),
                                    params: { title: "Home", move_id: create(:move).id, owner_membership_id: create(:membership).id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"].keys).to contain_exactly("move", "owner_membership")
    end

    it "doesn't let a member change the series" do
      post "/api/v1/sermon_series", headers: auth_headers(sarah.account), params: { title: "Mine" }
      expect(response).to have_http_status(:forbidden)

      patch "/api/v1/sermon_weeks/#{week1.id}", headers: auth_headers(sarah.account), params: { title: "Mine" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
