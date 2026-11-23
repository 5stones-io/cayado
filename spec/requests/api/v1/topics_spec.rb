require "rails_helper"

RSpec.describe "Topics API: the year's teaching diet", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church) }
  let(:linnea) { create(:membership, church: church) }

  let(:identity) { church.topics.find_by!(name: "Identity in Christ") }
  let(:prayer) { church.topics.find_by!(name: "Prayer") }
  let(:family) { church.topics.find_by!(name: "Family & Marriage") }

  before { use_tenant_host!(church) }

  def row(name) = json["topics"].find { _1["name"] == name }

  describe "GET /api/v1/topics" do
    it "maps each topic's weight month by month from the series that carry it, and sorts topics into gaps, healthy and heavy" do
      # Feb–Mar: identity 3, prayer 2.
      rooted = create(:sermon_series, church: church, title: "Rooted", starts_on: Date.new(2026, 2, 1), ends_on: Date.new(2026, 3, 8))
      Cayado::SeriesTopic.create!(sermon_series: rooted, topic: identity, weight: 3)
      Cayado::SeriesTopic.create!(sermon_series: rooted, topic: prayer, weight: 2)
      # Aug only: family 3. Dec 2025 → Jan 2026 counts only January.
      home = create(:sermon_series, church: church, title: "Home", starts_on: Date.new(2026, 8, 2), ends_on: Date.new(2026, 8, 23))
      Cayado::SeriesTopic.create!(sermon_series: home, topic: family, weight: 3)
      advent = create(:sermon_series, church: church, title: "Advent", starts_on: Date.new(2025, 12, 7), ends_on: Date.new(2026, 1, 4))
      Cayado::SeriesTopic.create!(sermon_series: advent, topic: prayer, weight: 1)
      # Other years and undated series don't count.
      later = create(:sermon_series, church: church, title: "Later", starts_on: Date.new(2027, 2, 7), ends_on: Date.new(2027, 2, 28))
      Cayado::SeriesTopic.create!(sermon_series: later, topic: family, weight: 3)
      undated = create(:sermon_series, church: church, title: "Undated", starts_on: nil, ends_on: nil)
      Cayado::SeriesTopic.create!(sermon_series: undated, topic: family, weight: 3)

      get "/api/v1/topics", headers: auth_headers(linnea.account), params: { year: 2026 }

      expect(response).to have_http_status(:ok)
      expect(json["year"]).to eq(2026)
      expect(json["topics"].map { _1["name"] }.first(3)).to eq(["Identity in Christ", "Prayer", "Discipleship"])
      expect(json["topics"].size).to eq(12)

      expect(row("Identity in Christ")).to include("id" => identity.id, "months" => [0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                                   "total" => 6, "months_hit" => 2, "status" => "heavy")
      expect(row("Prayer")).to include("months" => [1, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0], "total" => 5, "months_hit" => 3, "status" => "healthy")
      expect(row("Family & Marriage")).to include("months" => [0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0], "total" => 3, "status" => "healthy")
      expect(row("Generosity")).to include("total" => 0, "months_hit" => 0, "status" => "gap")

      expect(json["series"].map { _1["title"] }).to eq(%w[Advent Rooted Home])
      expect(json["series"][1]).to eq(
        "id" => rooted.id, "title" => "Rooted", "starts_on" => "2026-02-01", "ends_on" => "2026-03-08",
        "weights" => [{ "topic_id" => identity.id, "name" => "Identity in Christ", "weight" => 3 },
                      { "topic_id" => prayer.id, "name" => "Prayer", "weight" => 2 }],
      )
    end

    it "defaults to the church's current year" do
      travel_to(Time.utc(2026, 11, 23, 15)) do
        get "/api/v1/topics", headers: auth_headers(linnea.account)
      end

      expect(json["year"]).to eq(2026)
    end
  end

  describe "PUT /api/v1/sermon_series/:id/topics" do
    let(:series) { create(:sermon_series, church: church) }

    it "lets an admin set the series' weights, replacing the old ones; 0 leaves a topic out" do
      Cayado::SeriesTopic.create!(sermon_series: series, topic: family, weight: 2)

      put "/api/v1/sermon_series/#{series.id}/topics", headers: auth_headers(pastor.account),
                                                       params: { weights: { identity.id.to_s => 3, prayer.id.to_s => 1, family.id.to_s => 0 } }

      expect(response).to have_http_status(:ok)
      expect(json["weights"]).to eq([{ "topic_id" => identity.id, "name" => "Identity in Christ", "weight" => 3 },
                                     { "topic_id" => prayer.id, "name" => "Prayer", "weight" => 1 }])
      expect(series.series_topics.count).to eq(2)
    end

    it "re-weights a topic the series already carries" do
      Cayado::SeriesTopic.create!(sermon_series: series, topic: family, weight: 2)

      put "/api/v1/sermon_series/#{series.id}/topics", headers: auth_headers(pastor.account), params: { weights: { family.id.to_s => 3 } }

      expect(response).to have_http_status(:ok)
      expect(series.series_topics.pluck(:topic_id, :weight)).to eq([[family.id, 3]])
    end

    it "answers 422 for a weight over 3 or another church's topic, and changes nothing" do
      Cayado::SeriesTopic.create!(sermon_series: series, topic: family, weight: 2)
      other_topic = create(:church).topics.first

      put "/api/v1/sermon_series/#{series.id}/topics", headers: auth_headers(pastor.account), params: { weights: { identity.id.to_s => 4 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("invalid")

      put "/api/v1/sermon_series/#{series.id}/topics", headers: auth_headers(pastor.account), params: { weights: { other_topic.id.to_s => 2 } }
      expect(response).to have_http_status(:unprocessable_content)

      expect(series.series_topics.pluck(:topic_id, :weight)).to eq([[family.id, 2]])
    end

    it "is admin only" do
      put "/api/v1/sermon_series/#{series.id}/topics", headers: auth_headers(linnea.account), params: { weights: { identity.id.to_s => 3 } }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "the topic library" do
    it "lets an admin add (at the end), rename and remove topics; removing one drops its weights" do
      series = create(:sermon_series, church: church)
      Cayado::SeriesTopic.create!(sermon_series: series, topic: prayer, weight: 2)

      post "/api/v1/topics", headers: auth_headers(pastor.account), params: { name: "Sabbath" }
      expect(response).to have_http_status(:created)
      expect(json).to include("name" => "Sabbath")
      expect(church.topics.order(:position).last.name).to eq("Sabbath")

      patch "/api/v1/topics/#{prayer.id}", headers: auth_headers(pastor.account), params: { name: "Prayer & Fasting" }
      expect(response).to have_http_status(:ok)
      expect(json["name"]).to eq("Prayer & Fasting")

      delete "/api/v1/topics/#{prayer.id}", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(series.series_topics.count).to eq(0)
    end

    it "answers 422 for a duplicate or blank name" do
      post "/api/v1/topics", headers: auth_headers(pastor.account), params: { name: "Prayer" }
      expect(json["errors"]).to have_key("name")

      post "/api/v1/topics", headers: auth_headers(pastor.account), params: { name: "" }
      expect(json["errors"]).to have_key("name")
    end

    it "is admin only" do
      post "/api/v1/topics", headers: auth_headers(linnea.account), params: { name: "Sabbath" }
      expect(response).to have_http_status(:forbidden)

      delete "/api/v1/topics/#{prayer.id}", headers: auth_headers(linnea.account)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
