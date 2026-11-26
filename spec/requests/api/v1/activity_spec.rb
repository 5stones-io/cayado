require "rails_helper"

RSpec.describe "Activity: what the team did", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:sarah) { create(:membership, church: church, account: create(:account, first_name: "Sarah", last_name: "Whitfield")) }
  let(:elena) { create(:membership, church: church, account: create(:account, first_name: "Elena", last_name: "Park")) }
  let(:worship) { church.ministries.find_by!(key: "worship") }
  let(:series) { create(:sermon_series, church: church, title: "Rooted") }
  let(:week) { create(:sermon_week, sermon_series: series, position: 3, title: "Free in Christ") }

  before do
    worship.update!(lead_membership: elena)
    use_tenant_host!(church)
  end

  describe "recording" do
    it "records a comment on a week" do
      post "/api/v1/sermon_weeks/#{week.id}/comments", headers: auth_headers(pastor.account),
                                                       params: { body: "Love that. Keep 2:14 as the anchor." }

      expect(Cayado::ActivityEvent.sole).to have_attributes(
        kind: "comment_added", actor_membership: pastor, sermon_week: week, sermon_series: series,
        data: { "excerpt" => "Love that. Keep 2:14 as the anchor." }
      )
    end

    it "records a plan being written, once per save" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/worship", headers: auth_headers(elena.account), params: { body: "Living Hope" }
      put "/api/v1/sermon_weeks/#{week.id}/plans/worship", headers: auth_headers(elena.account), params: { body: "O Praise the Name" }

      expect(Cayado::ActivityEvent.pluck(:kind)).to eq(%w[plan_saved plan_saved])
      expect(Cayado::ActivityEvent.last.data).to eq("ministry_key" => "worship", "ministry_name" => "Worship",
                                                     "excerpt" => "O Praise the Name")
    end

    it "records nothing for a plan that didn't save" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/worship", headers: auth_headers(elena.account), params: { body: "" }

      expect(Cayado::ActivityEvent.count).to eq(0)
    end

    it "cuts a long comment down to an excerpt" do
      post "/api/v1/sermon_weeks/#{week.id}/comments", headers: auth_headers(pastor.account), params: { body: "word " * 100 }

      expect(Cayado::ActivityEvent.sole.data["excerpt"].length).to be <= 140
    end
  end

  describe "GET /api/v1/activity" do
    it "lists what everyone else did, newest first, with what's unread" do
      sarah.update!(activity_seen_at: 2.days.ago)
      create(:activity_event, church: church, actor_membership: elena, kind: "plan_saved", sermon_week: week,
                              data: { ministry_key: "worship", ministry_name: "Worship", excerpt: "Living Hope" },
                              created_at: 3.days.ago)
      create(:activity_event, church: church, actor_membership: pastor, kind: "comment_added", sermon_week: week,
                              data: { excerpt: "Love that." }, created_at: 1.day.ago)
      create(:activity_event, church: church, actor_membership: sarah, kind: "comment_added", sermon_week: week)

      get "/api/v1/activity", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json["unread_count"]).to eq(1)
      expect(json["events"].map { _1.slice("kind", "unread") }).to eq([
        { "kind" => "comment_added", "unread" => true },
        { "kind" => "plan_saved", "unread" => false },
      ])
      expect(json["events"].first).to include(
        "actor" => include("name" => "David Chen", "initials" => "DC"),
        "excerpt" => "Love that.",
        "sermon_week" => { "id" => week.id, "position" => 3, "title" => "Free in Christ" },
        "sermon_series" => { "id" => series.id, "title" => "Rooted" }
      )
      expect(json["events"].second).to include("ministry" => { "key" => "worship", "name" => "Worship" })
    end

    it "treats everything as unread for someone who's never looked" do
      create(:activity_event, church: church, actor_membership: pastor, kind: "comment_added", sermon_week: week)

      get "/api/v1/activity", headers: auth_headers(sarah.account)

      expect(json["unread_count"]).to eq(1)
    end

    it "shows a heads-up only to the people it was sent to" do
      create(:activity_event, church: church, actor_membership: pastor, kind: "team_notified", sermon_series: series,
                              data: { recipient_ids: [elena.id], subject: "Heads up — Rooted is on the calendar." })

      get "/api/v1/activity", headers: auth_headers(sarah.account)
      expect(json["events"]).to eq([])

      get "/api/v1/activity", headers: auth_headers(elena.account)
      expect(json["events"].sole).to include("kind" => "team_notified",
                                             "excerpt" => "Heads up — Rooted is on the calendar.",
                                             "sermon_week" => nil,
                                             "sermon_series" => { "id" => series.id, "title" => "Rooted" })
    end

    it "pages with before" do
      events = Array.new(3) do |i|
        create(:activity_event, church: church, actor_membership: pastor, kind: "comment_added", sermon_week: week,
                                created_at: (3 - i).hours.ago)
      end

      get "/api/v1/activity", headers: auth_headers(sarah.account), params: { limit: 2 }
      expect(json["events"].map { _1["id"] }).to eq([events[2].id, events[1].id])
      expect(json["next_before"]).to eq(events[1].id)

      get "/api/v1/activity", headers: auth_headers(sarah.account), params: { limit: 2, before: json["next_before"] }
      expect(json["events"].map { _1["id"] }).to eq([events[0].id])
      expect(json["next_before"]).to be_nil
    end

    it "keeps a former teammate's activity without an actor" do
      create(:activity_event, church: church, actor_membership: elena, kind: "comment_added", sermon_week: week)
      elena.destroy!

      get "/api/v1/activity", headers: auth_headers(sarah.account)

      expect(json["events"].sole["actor"]).to be_nil
    end

    it "doesn't show another church's activity" do
      other = create(:church)
      create(:activity_event, church: other, actor_membership: create(:membership, church: other), kind: "comment_added")

      get "/api/v1/activity", headers: auth_headers(sarah.account)

      expect(json["events"]).to eq([])
    end
  end

  describe "POST /api/v1/activity/seen" do
    it "marks everything read" do
      create(:activity_event, church: church, actor_membership: pastor, kind: "comment_added", sermon_week: week,
                              created_at: 1.minute.ago)

      post "/api/v1/activity/seen", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:no_content)
      expect(sarah.reload.activity_seen_at).to be_within(5.seconds).of(Time.current)
      get "/api/v1/activity", headers: auth_headers(sarah.account)
      expect(json["unread_count"]).to eq(0)
    end
  end
end
