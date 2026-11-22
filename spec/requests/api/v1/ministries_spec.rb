require "rails_helper"

RSpec.describe "Ministries and team API", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, title: "Lead Pastor", account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:sarah) { create(:membership, church: church, title: "Kids Pastor", account: create(:account, first_name: "Sarah", last_name: "Whitfield")) }

  before { use_tenant_host!(church) }

  describe "GET /api/v1/ministries" do
    it "lists the church's ministries in order with their leads" do
      church.ministries.find_by!(key: "kids").update!(lead_membership: sarah)

      get "/api/v1/ministries", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json["ministries"].map { _1["key"] }).to eq(%w[kids youth small-groups worship])
      expect(json["ministries"].first).to include(
        "key" => "kids", "name" => "Kids", "color" => "sky", "position" => 0,
        "lead" => include("membership_id" => sarah.id, "name" => "Sarah Whitfield")
      )
      expect(json["ministries"].second["lead"]).to be_nil
    end
  end

  describe "POST /api/v1/ministries" do
    it "lets an admin add a ministry at the end" do
      post "/api/v1/ministries", headers: auth_headers(pastor.account),
                                 params: { key: "outreach", name: "Outreach", color: "ink", lead_membership_id: sarah.id }

      expect(response).to have_http_status(:created)
      expect(json).to include("key" => "outreach", "position" => 4, "lead" => include("membership_id" => sarah.id))
      expect(church.ministries.reload.last.key).to eq("outreach")
    end

    it "answers 422 for a key already in use" do
      post "/api/v1/ministries", headers: auth_headers(pastor.account), params: { key: "kids", name: "Kids 2", color: "ink" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("key")
    end

    it "is admin only" do
      post "/api/v1/ministries", headers: auth_headers(sarah.account), params: { key: "mine", name: "Mine", color: "ink" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/ministries/:key" do
    it "lets an admin rename, recolor and set the lead, but not change the key" do
      patch "/api/v1/ministries/youth", headers: auth_headers(pastor.account),
                                        params: { key: "students", name: "Students", color: "sage", lead_membership_id: sarah.id }

      expect(response).to have_http_status(:ok)
      expect(json).to include("key" => "youth", "name" => "Students", "color" => "sage", "lead" => include("membership_id" => sarah.id))
    end

    it "clears the lead" do
      church.ministries.find_by!(key: "kids").update!(lead_membership: sarah)

      patch "/api/v1/ministries/kids", headers: auth_headers(pastor.account), params: { lead_membership_id: "" }

      expect(json["lead"]).to be_nil
    end

    it "answers 422 for a lead from another church" do
      patch "/api/v1/ministries/kids", headers: auth_headers(pastor.account), params: { lead_membership_id: create(:membership).id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("lead_membership")
    end

    it "answers 404 for an unknown key" do
      patch "/api/v1/ministries/choir", headers: auth_headers(pastor.account), params: { name: "Choir" }

      expect(response).to have_http_status(:not_found)
    end

    it "is admin only, even for the ministry's lead" do
      church.ministries.find_by!(key: "kids").update!(lead_membership: sarah)

      patch "/api/v1/ministries/kids", headers: auth_headers(sarah.account), params: { name: "Little Ones" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/ministries/:key" do
    it "lets an admin remove a ministry and its plans" do
      worship = church.ministries.find_by!(key: "worship")
      create(:alignment_plan, ministry: worship, sermon_week: create(:sermon_week, sermon_series: create(:sermon_series, church: church)))

      delete "/api/v1/ministries/worship", headers: auth_headers(pastor.account)

      expect(response).to have_http_status(:no_content)
      expect(church.ministries.reload.map(&:key)).to eq(%w[kids youth small-groups])
      expect(Cayado::AlignmentPlan.where(ministry_id: worship.id)).to be_empty
    end

    it "is admin only" do
      delete "/api/v1/ministries/worship", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/team" do
    it "lists everyone on this church's staff by name, with their role, for pickers" do
      pastor && sarah
      create(:membership) # another church

      get "/api/v1/team", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json["team"]).to eq([
        { "membership_id" => pastor.id, "name" => "David Chen", "title" => "Lead Pastor", "initials" => "DC", "role" => "admin" },
        { "membership_id" => sarah.id, "name" => "Sarah Whitfield", "title" => "Kids Pastor", "initials" => "SW", "role" => "member" },
      ])
    end
  end
end
