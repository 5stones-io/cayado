require "rails_helper"

RSpec.describe "Sermon week API: alignment plans and the conversation", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:sarah) { create(:membership, church: church, title: "Kids Pastor", account: create(:account, first_name: "Sarah", last_name: "Whitfield")) }
  let(:jordan) { create(:membership, church: church, title: "Youth Pastor") }
  let(:kids) { church.ministries.find_by!(key: "kids") }
  let(:series) { create(:sermon_series, church: church, title: "Rooted") }
  let(:week) { create(:sermon_week, sermon_series: series, position: 3, preached_on: Date.new(2026, 2, 22), title: "Free in Christ") }

  before do
    kids.update!(lead_membership: sarah)
    use_tenant_host!(church)
  end

  describe "GET /api/v1/sermon_weeks/:id" do
    it "gives the week, its series, the slots and the conversation oldest first" do
      first = create(:comment, sermon_week: week, membership: sarah, body: "1:16 or 1:17?", created_at: 2.hours.ago)
      create(:comment, sermon_week: week, membership: pastor, body: "1:17 — yes.", created_at: 1.hour.ago)

      get "/api/v1/sermon_weeks/#{week.id}", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => week.id, "title" => "Free in Christ", "series" => { "id" => series.id, "title" => "Rooted" })
      expect(json["slots"].size).to eq(4)
      expect(json["comments"].map { _1["body"] }).to eq(["1:16 or 1:17?", "1:17 — yes."])
      expect(json["comments"].first).to include("id" => first.id, "mine" => true,
                                                "author" => include("name" => "Sarah Whitfield", "initials" => "SW"))
      expect(json["comments"].second["mine"]).to be(false)
    end

    it "shows a former teammate's comment without an author" do
      comment = create(:comment, sermon_week: week, membership: jordan)
      jordan.destroy!

      get "/api/v1/sermon_weeks/#{week.id}", headers: auth_headers(sarah.account)

      expect(json["comments"].sole).to include("id" => comment.id, "author" => nil, "mine" => false)
    end
  end

  describe "PUT /api/v1/sermon_weeks/:id/plans/:ministry_key" do
    it "lets the ministry's lead write their plan, then change it" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/kids", headers: auth_headers(sarah.account),
                                                        params: { body: "Chains craft", memory_verse: "Col 2:14" }

      expect(response).to have_http_status(:ok)
      expect(json).to include("ministry" => include("key" => "kids"), "can_edit" => true)
      expect(json["plan"]).to include("body" => "Chains craft", "memory_verse" => "Col 2:14")

      put "/api/v1/sermon_weeks/#{week.id}/plans/kids", headers: auth_headers(sarah.account), params: { body: "Chains object lesson" }

      plan = week.alignment_plans.sole
      expect(plan).to have_attributes(body: "Chains object lesson", updated_by_membership: sarah)
    end

    it "lets an admin write any ministry's plan" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/youth", headers: auth_headers(pastor.account), params: { body: "Testimony night" }

      expect(response).to have_http_status(:ok)
      expect(week.alignment_plans.sole.updated_by_membership).to eq(pastor)
    end

    it "doesn't let someone write another ministry's plan" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/kids", headers: auth_headers(jordan.account), params: { body: "Mine" }

      expect(response).to have_http_status(:forbidden)
      expect(week.alignment_plans).to be_empty
    end

    it "needs something in the plan" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/kids", headers: auth_headers(sarah.account), params: { body: " " }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is a 404 for a ministry the church doesn't have" do
      put "/api/v1/sermon_weeks/#{week.id}/plans/choir", headers: auth_headers(pastor.account), params: { body: "x" }

      expect(response).to have_http_status(:not_found)
    end

    it "goes back to awaiting when the plan is cleared" do
      create(:alignment_plan, sermon_week: week, ministry: kids)

      delete "/api/v1/sermon_weeks/#{week.id}/plans/kids", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json["plan"]).to be_nil
      expect(week.alignment_plans).to be_empty
    end
  end

  describe "comments" do
    it "lets anyone on staff join the conversation" do
      post "/api/v1/sermon_weeks/#{week.id}/comments", headers: auth_headers(jordan.account), params: { body: "Testimony night?" }

      expect(response).to have_http_status(:created)
      expect(json).to include("body" => "Testimony night?", "mine" => true)
      expect(week.comments.sole.membership).to eq(jordan)
    end

    it "won't post an empty comment" do
      post "/api/v1/sermon_weeks/#{week.id}/comments", headers: auth_headers(jordan.account), params: { body: "" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "lets the author or an admin delete a comment, but nobody else" do
      mine = create(:comment, sermon_week: week, membership: jordan)
      theirs = create(:comment, sermon_week: week, membership: sarah)

      delete "/api/v1/comments/#{theirs.id}", headers: auth_headers(jordan.account)
      expect(response).to have_http_status(:forbidden)

      delete "/api/v1/comments/#{mine.id}", headers: auth_headers(jordan.account)
      expect(response).to have_http_status(:no_content)

      delete "/api/v1/comments/#{theirs.id}", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(week.comments).to be_empty
    end
  end

  it "is a 404 for another church's week" do
    other = create(:sermon_week)

    get "/api/v1/sermon_weeks/#{other.id}", headers: auth_headers(sarah.account)
    expect(response).to have_http_status(:not_found)

    post "/api/v1/sermon_weeks/#{other.id}/comments", headers: auth_headers(sarah.account), params: { body: "hi" }
    expect(response).to have_http_status(:not_found)
  end
end
