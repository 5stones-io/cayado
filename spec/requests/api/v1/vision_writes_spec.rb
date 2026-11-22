require "rails_helper"

RSpec.describe "Vision API: writing the vision, pillars, moves and years", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church) }
  let(:linnea) { create(:membership, church: church, title: "Small Groups Director", account: create(:account, first_name: "Linnea", last_name: "Hoffman")) }
  let(:jordan) { create(:membership, church: church, title: "Youth Pastor") }

  before { use_tenant_host!(church) }

  describe "PUT /api/v1/vision" do
    it "lets an admin write the church's vision, then change it" do
      put "/api/v1/vision", headers: auth_headers(pastor.account),
                            params: { title: "2026–2030 Vision", subtitle: "Reach, disciple, send", start_year: 2026, end_year: 2030 }

      expect(response).to have_http_status(:created)
      expect(json).to include("title" => "2026–2030 Vision", "start_year" => 2026, "end_year" => 2030, "pillars" => [], "years" => [])

      put "/api/v1/vision", headers: auth_headers(pastor.account), params: { subtitle: "Reach, disciple, send out" }

      expect(response).to have_http_status(:ok)
      expect(church.reload.vision).to have_attributes(title: "2026–2030 Vision", subtitle: "Reach, disciple, send out")
    end

    it "answers 422 for years that run backwards" do
      put "/api/v1/vision", headers: auth_headers(pastor.account), params: { title: "Vision", start_year: 2030, end_year: 2026 }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("end_year")
    end

    it "is admin only" do
      put "/api/v1/vision", headers: auth_headers(linnea.account), params: { title: "Mine now" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with a vision" do
    let!(:vision) { create(:vision, church: church, start_year: 2026, end_year: 2030) }
    let!(:disciple) { create(:pillar, vision: vision, position: 1, title: "Disciple", tone: "sage") }

    before { Cayado::PillarEditor.create!(pillar: disciple, membership: linnea) }

    describe "POST /api/v1/vision/pillars" do
      it "lets an admin add a pillar at the end" do
        post "/api/v1/vision/pillars", headers: auth_headers(pastor.account),
                                       params: { title: "Send", tone: "terracotta", blurb: "Every member a missionary" }

        expect(response).to have_http_status(:created)
        expect(json).to include("title" => "Send", "tone" => "terracotta", "can_edit" => true, "editors" => [], "moves" => [])
        expect(vision.pillars.reload.map(&:title)).to eq(%w[Disciple Send])
      end

      it "answers 422 for an unknown tone" do
        post "/api/v1/vision/pillars", headers: auth_headers(pastor.account), params: { title: "Send", tone: "neon" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to have_key("tone")
      end

      it "is admin only, even for a pillar editor" do
        post "/api/v1/vision/pillars", headers: auth_headers(linnea.account), params: { title: "Send", tone: "ink" }

        expect(response).to have_http_status(:forbidden)
      end

      it "is not found before the church has a vision" do
        vision.destroy!

        post "/api/v1/vision/pillars", headers: auth_headers(pastor.account), params: { title: "Send", tone: "ink" }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "PATCH /api/v1/pillars/:id" do
      it "lets a named editor change their pillar's words" do
        patch "/api/v1/pillars/#{disciple.id}", headers: auth_headers(linnea.account), params: { blurb: "Ordinary disciples" }

        expect(response).to have_http_status(:ok)
        expect(json).to include("blurb" => "Ordinary disciples", "can_edit" => true)
      end

      it "doesn't let anyone else on staff edit it" do
        patch "/api/v1/pillars/#{disciple.id}", headers: auth_headers(jordan.account), params: { blurb: "Mine" }

        expect(response).to have_http_status(:forbidden)
        expect(disciple.reload.blurb).to be_nil
      end

      it "lets an admin name the pillar's editors" do
        patch "/api/v1/pillars/#{disciple.id}", headers: auth_headers(pastor.account), params: { editor_membership_ids: [jordan.id] }

        expect(response).to have_http_status(:ok)
        expect(json["editors"].map { _1["membership_id"] }).to eq([jordan.id])
        expect(disciple.reload.editors).to eq([jordan])
      end

      it "clears the editors when an admin sends an empty list" do
        patch "/api/v1/pillars/#{disciple.id}", headers: auth_headers(pastor.account),
                                                params: { editor_membership_ids: [""] }

        expect(json["editors"]).to eq([])
      end

      it "doesn't let an editor change who the editors are" do
        patch "/api/v1/pillars/#{disciple.id}", headers: auth_headers(linnea.account), params: { editor_membership_ids: [jordan.id] }

        expect(response).to have_http_status(:forbidden)
        expect(disciple.reload.editors).to eq([linnea])
      end

      it "answers 422 for an editor from another church" do
        stranger = create(:membership)

        patch "/api/v1/pillars/#{disciple.id}", headers: auth_headers(pastor.account), params: { editor_membership_ids: [stranger.id] }

        expect(response).to have_http_status(:unprocessable_content)
        expect(disciple.reload.editors).to eq([linnea])
      end

      it "doesn't find another church's pillar" do
        other = create(:pillar, vision: create(:vision))

        patch "/api/v1/pillars/#{other.id}", headers: auth_headers(pastor.account), params: { title: "Mine" }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /api/v1/pillars/:id" do
      it "lets an admin remove a pillar and its moves; series that advanced them stay" do
        move = create(:move, pillar: disciple)
        series = create(:sermon_series, church: church, move: move)

        delete "/api/v1/pillars/#{disciple.id}", headers: auth_headers(pastor.account)

        expect(response).to have_http_status(:no_content)
        expect(Cayado::Move.exists?(move.id)).to be(false)
        expect(series.reload.move).to be_nil
      end

      it "is admin only, even for the pillar's editor" do
        delete "/api/v1/pillars/#{disciple.id}", headers: auth_headers(linnea.account)

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "moves" do
      it "lets a pillar's editor add, reword and remove its moves" do
        post "/api/v1/pillars/#{disciple.id}/moves", headers: auth_headers(linnea.account), params: { text: "Re-launch small groups" }

        expect(response).to have_http_status(:created)
        expect(json).to include("text" => "Re-launch small groups", "sermon_series" => [])
        move_id = json["id"]

        patch "/api/v1/moves/#{move_id}", headers: auth_headers(linnea.account), params: { text: "Re-launch groups by fall" }

        expect(response).to have_http_status(:ok)
        expect(json["text"]).to eq("Re-launch groups by fall")

        delete "/api/v1/moves/#{move_id}", headers: auth_headers(linnea.account)

        expect(response).to have_http_status(:no_content)
        expect(disciple.moves.reload).to be_empty
      end

      it "adds a move after the pillar's last one" do
        create(:move, pillar: disciple, position: 4, text: "First")

        post "/api/v1/pillars/#{disciple.id}/moves", headers: auth_headers(pastor.account), params: { text: "Second" }

        expect(disciple.moves.reload.map(&:text)).to eq(%w[First Second])
      end

      it "doesn't let someone who can't edit the pillar touch its moves" do
        move = create(:move, pillar: disciple)

        post "/api/v1/pillars/#{disciple.id}/moves", headers: auth_headers(jordan.account), params: { text: "Mine" }
        expect(response).to have_http_status(:forbidden)

        patch "/api/v1/moves/#{move.id}", headers: auth_headers(jordan.account), params: { text: "Mine" }
        expect(response).to have_http_status(:forbidden)

        delete "/api/v1/moves/#{move.id}", headers: auth_headers(jordan.account)
        expect(response).to have_http_status(:forbidden)
        expect(move.reload.text).not_to eq("Mine")
      end

      it "answers 422 for a blank move" do
        post "/api/v1/pillars/#{disciple.id}/moves", headers: auth_headers(linnea.account), params: { text: "" }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "doesn't find another church's move" do
        other = create(:move, pillar: create(:pillar, vision: create(:vision)))

        patch "/api/v1/moves/#{other.id}", headers: auth_headers(pastor.account), params: { text: "Mine" }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "PUT /api/v1/vision/years/:year" do
      it "lets an admin write a year of the ladder, then change it" do
        put "/api/v1/vision/years/2026", headers: auth_headers(pastor.account),
                                         params: { headline: "Year of Foundations", goals: ["Launch Rooted", "Hire"] }

        expect(response).to have_http_status(:ok)
        expect(json).to eq("year" => 2026, "headline" => "Year of Foundations", "goals" => ["Launch Rooted", "Hire"])

        put "/api/v1/vision/years/2026", headers: auth_headers(pastor.account), params: { goals: ["Launch Rooted"] }

        expect(vision.horizon_years.sole).to have_attributes(headline: "Year of Foundations", goals: ["Launch Rooted"])
      end

      it "clears a year's goals when sent an empty list" do
        create(:horizon_year, vision: vision, year: 2027, goals: ["Open Reston"])

        put "/api/v1/vision/years/2027", headers: auth_headers(pastor.account), params: { goals: [""] }

        expect(json["goals"]).to eq([])
      end

      it "answers 422 for a year outside the vision" do
        put "/api/v1/vision/years/2031", headers: auth_headers(pastor.account), params: { headline: "Too far" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to have_key("year")
      end

      it "lets an admin remove a year" do
        create(:horizon_year, vision: vision, year: 2028)

        delete "/api/v1/vision/years/2028", headers: auth_headers(pastor.account)

        expect(response).to have_http_status(:no_content)
        expect(vision.horizon_years.reload).to be_empty
      end

      it "is admin only" do
        put "/api/v1/vision/years/2026", headers: auth_headers(linnea.account), params: { headline: "Mine" }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
