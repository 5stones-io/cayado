require "rails_helper"

RSpec.describe "Congregation and pinned snapshots", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church) }
  let(:sarah) { create(:membership, church: church) }
  let(:rooted) { create(:sermon_series, church: church, title: "Rooted") }
  let(:week) { create(:sermon_week, sermon_series: rooted, position: 3, title: "Free in Christ", preached_on: Date.new(2026, 3, 1)) }

  let(:life_stages) do
    [{ "label" => "Young families with kids", "pct" => 32 }, { "label" => "Singles & young adults", "pct" => 18 }]
  end
  let(:season_markers) { [{ "label" => "births", "count" => 7 }, { "label" => "funerals", "count" => 3 }] }

  around { |example| travel_to(Time.zone.parse("2026-03-02 09:00 America/Chicago")) { example.run } }
  before { use_tenant_host!(church) }

  describe "GET /api/v1/congregation" do
    it "is empty until a snapshot is taken" do
      get "/api/v1/congregation", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "stats" => { "avg_attendance" => nil, "first_time_guests_this_month" => 0,
                     "first_time_guests_vs_3mo" => nil, "households" => nil },
        "snapshot" => nil
      )
    end

    it "shows the latest snapshot, the weeks it's pinned to and the headline numbers" do
      create(:congregation_snapshot, church: church, taken_on: Date.new(2026, 1, 5), households: 390)
      latest = create(:congregation_snapshot, church: church, taken_on: Date.new(2026, 2, 20), households: 412,
                                              life_stages: life_stages, season_markers: season_markers,
                                              note: "Lead with hope and lament held together.")
      week.update!(congregation_snapshot: latest)
      create(:weekly_metric, church: church, week_of: Date.new(2026, 3, 1), attendance: 847, first_time_guests: 38)

      get "/api/v1/congregation", headers: auth_headers(sarah.account)

      expect(json["stats"]).to eq("avg_attendance" => 847, "first_time_guests_this_month" => 38,
                                  "first_time_guests_vs_3mo" => nil, "households" => 412)
      expect(json["snapshot"]).to eq(
        "id" => latest.id, "taken_on" => "2026-02-20", "households" => 412,
        "life_stages" => life_stages, "season_markers" => season_markers,
        "note" => "Lead with hope and lament held together.",
        "pinned_weeks" => [{ "id" => week.id, "position" => 3, "title" => "Free in Christ",
                             "preached_on" => "2026-03-01", "series" => { "id" => rooted.id, "title" => "Rooted" } }]
      )
    end

    it "doesn't show another church's snapshot" do
      create(:congregation_snapshot, church: create(:church))

      get "/api/v1/congregation", headers: auth_headers(sarah.account)

      expect(json["snapshot"]).to be_nil
    end
  end

  describe "snapshots (admin, manual until Planning Center)" do
    it "takes a snapshot dated today unless told otherwise" do
      post "/api/v1/congregation_snapshots", headers: auth_headers(pastor.account),
           params: { households: 412, life_stages: life_stages, season_markers: season_markers, note: "Hope." }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("taken_on" => "2026-03-02", "households" => 412, "life_stages" => life_stages,
                              "season_markers" => season_markers, "note" => "Hope.", "pinned_weeks" => [])
    end

    it "corrects and deletes a snapshot" do
      snapshot = create(:congregation_snapshot, church: church)
      week.update!(congregation_snapshot: snapshot)

      patch "/api/v1/congregation_snapshots/#{snapshot.id}", headers: auth_headers(pastor.account),
            params: { households: 420 }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json["households"]).to eq(420)

      patch "/api/v1/congregation_snapshots/#{snapshot.id}", headers: auth_headers(pastor.account),
            params: { life_stages: [{ label: "Seniors", pct: 140 }] }, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      delete "/api/v1/congregation_snapshots/#{snapshot.id}", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(week.reload.congregation_snapshot_id).to be_nil
    end

    it "keeps snapshot writes to admins" do
      snapshot = create(:congregation_snapshot, church: church)

      post "/api/v1/congregation_snapshots", headers: auth_headers(sarah.account), params: { households: 1 }, as: :json
      expect(response).to have_http_status(:forbidden)
      patch "/api/v1/congregation_snapshots/#{snapshot.id}", headers: auth_headers(sarah.account), params: { households: 1 }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "pinning a snapshot to a sermon week" do
    it "pins the latest snapshot by default and shows it on the week" do
      create(:congregation_snapshot, church: church, taken_on: Date.new(2026, 1, 5))
      latest = create(:congregation_snapshot, church: church, taken_on: Date.new(2026, 2, 20))

      put "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(pastor.account)

      expect(response).to have_http_status(:ok)
      expect(json).to eq("sermon_week_id" => week.id, "congregation_snapshot_id" => latest.id)

      get "/api/v1/sermon_weeks/#{week.id}", headers: auth_headers(sarah.account)
      expect(json["congregation_snapshot_id"]).to eq(latest.id)
    end

    it "pins a chosen snapshot, and unpins" do
      older = create(:congregation_snapshot, church: church, taken_on: Date.new(2026, 1, 5))
      create(:congregation_snapshot, church: church, taken_on: Date.new(2026, 2, 20))

      put "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(pastor.account),
          params: { congregation_snapshot_id: older.id }, as: :json
      expect(json["congregation_snapshot_id"]).to eq(older.id)

      delete "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(week.reload.congregation_snapshot_id).to be_nil
    end

    it "has nothing to pin before a snapshot exists" do
      put "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(pastor.account)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("no_snapshot")
    end

    it "won't pin another church's snapshot, or pin to another church's week" do
      theirs = create(:congregation_snapshot, church: create(:church))
      put "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(pastor.account),
          params: { congregation_snapshot_id: theirs.id }, as: :json
      expect(response).to have_http_status(:not_found)

      create(:congregation_snapshot, church: church)
      their_week = create(:sermon_week, sermon_series: create(:sermon_series, church: create(:church)))
      put "/api/v1/sermon_weeks/#{their_week.id}/snapshot", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:not_found)
    end

    it "keeps pinning to admins" do
      create(:congregation_snapshot, church: church)

      put "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(sarah.account)
      expect(response).to have_http_status(:forbidden)
      delete "/api/v1/sermon_weeks/#{week.id}/snapshot", headers: auth_headers(sarah.account)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
