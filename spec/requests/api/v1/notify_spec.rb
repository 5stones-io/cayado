require "rails_helper"

RSpec.describe "Notify team about a sermon series", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:sarah) { create(:membership, church: church, account: create(:account, email: "sarah@jcc.org", first_name: "Sarah", last_name: "Whitfield")) }
  let(:elena) { create(:membership, church: church, account: create(:account, email: "elena@jcc.org", first_name: "Elena", last_name: "Park")) }
  let(:series) { create(:sermon_series, church: church, title: "Rooted") }

  before do
    church.ministries.find_by!(key: "kids").update!(lead_membership: sarah)
    church.ministries.find_by!(key: "worship").update!(lead_membership: elena)
    # Leading two ministries is still one heads-up.
    church.ministries.find_by!(key: "youth").update!(lead_membership: elena)
    # The sender doesn't notify themselves.
    church.ministries.find_by!(key: "small-groups").update!(lead_membership: pastor)
    use_tenant_host!(church)
    allow(TeamEmail).to receive(:heads_up)
  end

  describe "GET /api/v1/sermon_series/:id/notify" do
    it "previews who gets it and what it says" do
      get "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(pastor.account)

      expect(response).to have_http_status(:ok)
      expect(json["recipients"].map { _1["name"] }).to eq(["Elena Park", "Sarah Whitfield"])
      expect(json["channels"]).to eq(%w[email push])
      expect(json["subject"]).to eq("Heads up — Rooted is on the calendar.")
      expect(json["body"]).to eq("Plans, alignment slots, and conversations are open in Cayado. " \
                                 "Take a look this week and add your piece. — David Chen")
    end

    it "is for admins" do
      get "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/sermon_series/:id/notify" do
    it "emails each lead and puts a heads-up in their activity" do
      post "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(pastor.account),
                                                        params: { channels: %w[email push] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["notified"]).to eq(2)
      expect(TeamEmail).to have_received(:heads_up).twice
      expect(TeamEmail).to have_received(:heads_up).with(
        to: "sarah@jcc.org", church_name: church.brand_name, subject: "Heads up — Rooted is on the calendar.",
        body: a_string_ending_with("— David Chen"), link: a_string_including("sermons")
      )

      event = Cayado::ActivityEvent.sole
      expect(event).to have_attributes(kind: "team_notified", actor_membership: pastor, sermon_series: series)
      expect(event.data["recipient_ids"]).to contain_exactly(sarah.id, elena.id)
    end

    it "only puts it in the app when email is unticked" do
      post "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(pastor.account),
                                                        params: { channels: %w[push] }, as: :json

      expect(response).to have_http_status(:created)
      expect(TeamEmail).not_to have_received(:heads_up)
      expect(Cayado::ActivityEvent.sole.kind).to eq("team_notified")
    end

    it "takes the pastor's own wording" do
      post "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(pastor.account),
                                                        params: { channels: %w[email], body: "Start praying now." }, as: :json

      expect(TeamEmail).to have_received(:heads_up).with(hash_including(body: "Start praying now.")).twice
    end

    it "refuses a channel it doesn't have" do
      post "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(pastor.account),
                                                        params: { channels: %w[slack] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("invalid_channels")
      expect(Cayado::ActivityEvent.count).to eq(0)
    end

    it "refuses when no ministry has a lead to tell" do
      church.ministries.update_all(lead_membership_id: nil)

      post "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(pastor.account),
                                                        params: { channels: %w[email] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("no_recipients")
    end

    it "is for admins" do
      post "/api/v1/sermon_series/#{series.id}/notify", headers: auth_headers(sarah.account),
                                                        params: { channels: %w[email] }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(TeamEmail).not_to have_received(:heads_up)
    end

    it "is a 404 for another church's series" do
      other = create(:sermon_series, church: create(:church))

      post "/api/v1/sermon_series/#{other.id}/notify", headers: auth_headers(pastor.account),
                                                       params: { channels: %w[email] }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
