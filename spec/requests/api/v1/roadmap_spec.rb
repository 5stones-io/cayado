require "rails_helper"

RSpec.describe "Roadmap API: the year on one canvas, and the docs attached to it", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church, title: "Lead Pastor", account: create(:account, first_name: "David", last_name: "Chen")) }
  let(:marcus) { create(:membership, church: church, title: "Exec Pastor", account: create(:account, first_name: "Marcus", last_name: "Reyes")) }
  let(:elena) { create(:membership, church: church, title: "Worship Pastor", account: create(:account, first_name: "Elena", last_name: "Park")) }

  let(:vision) { create(:vision, church: church) }
  let(:reach) { create(:pillar, vision: vision, title: "Reach", tone: "terracotta") }
  let(:sundays) { create(:move, pillar: reach, text: "Plant a second Sunday gathering") }
  let(:disciple) { create(:pillar, vision: vision, title: "Disciple", tone: "sage") }
  let(:rooted_move) { create(:move, pillar: disciple, text: "Re-launch small groups around Rooted") }

  let!(:rooted) do
    create(:sermon_series, church: church, title: "Rooted", theme: "A study of Colossians", starts_on: Date.new(2026, 2, 1),
                           ends_on: Date.new(2026, 3, 8), owner_membership: pastor, move: rooted_move)
  end
  let!(:easter) do
    create(:roadmap_item, church: church, lane: "major_event", title: "Easter Sunday", starts_on: Date.new(2026, 4, 5),
                          ends_on: Date.new(2026, 4, 5), color: "gold", owner_membership: elena,
                          notes: "Two services, brass ensemble.", move: sundays)
  end

  before { use_tenant_host!(church) }

  def person(membership, name, title)
    { "membership_id" => membership.id, "name" => name, "title" => title, "initials" => name.split.map { _1[0] }.join }
  end

  describe "GET /api/v1/roadmap" do
    it "lays the year's series and items into the four lanes, series coming from the Sermons screen" do
      create(:sermon_week, sermon_series: rooted, position: 1, preached_on: Date.new(2026, 2, 1), title: "The Supremacy of Christ")
      create(:roadmap_item, church: church, lane: "outreach", title: "Summer Nights", starts_on: Date.new(2026, 6, 7),
                            ends_on: Date.new(2026, 7, 19), color: "sage", pillar: reach)
      create(:attachment, attachable: easter, owner_membership: marcus)

      get "/api/v1/roadmap", headers: auth_headers(marcus.account), params: { year: 2026 }

      expect(response).to have_http_status(:ok)
      expect(json["year"]).to eq(2026)
      expect(json["lanes"].map { _1["key"] }).to eq(%w[sermon_series major_event outreach ministry_initiative])
      expect(json["lanes"].map { _1["name"] }).to eq(["Sermon Series", "Major Events", "Outreach", "Ministry Initiatives"])

      series_lane, events, outreach, initiatives = json["lanes"]
      expect(series_lane["items"]).to eq([{
        "kind" => "sermon_series", "id" => rooted.id, "lane" => "sermon_series", "title" => "Rooted",
        "starts_on" => "2026-02-01", "ends_on" => "2026-03-08", "color" => "ink", "notes" => "A study of Colossians",
        "owner" => person(pastor, "David Chen", "Lead Pastor"),
        "advances" => { "pillar" => { "id" => disciple.id, "title" => "Disciple", "tone" => "sage" },
                        "move" => { "id" => rooted_move.id, "text" => "Re-launch small groups around Rooted" } },
        "attachments_count" => 0, "can_edit" => false,
        "weeks" => [{ "id" => rooted.weeks.first.id, "position" => 1, "preached_on" => "2026-02-01", "title" => "The Supremacy of Christ" }],
      }])
      expect(events["items"]).to eq([{
        "kind" => "roadmap_item", "id" => easter.id, "lane" => "major_event", "title" => "Easter Sunday",
        "starts_on" => "2026-04-05", "ends_on" => "2026-04-05", "color" => "gold", "notes" => "Two services, brass ensemble.",
        "owner" => person(elena, "Elena Park", "Worship Pastor"),
        "advances" => { "pillar" => { "id" => reach.id, "title" => "Reach", "tone" => "terracotta" },
                        "move" => { "id" => sundays.id, "text" => "Plant a second Sunday gathering" } },
        "attachments_count" => 1, "can_edit" => false,
      }])
      expect(outreach["items"].sole).to include("title" => "Summer Nights",
                                                "advances" => { "pillar" => { "id" => reach.id, "title" => "Reach", "tone" => "terracotta" }, "move" => nil })
      expect(initiatives["items"]).to eq([])
    end

    it "only shows what touches that year, from this church, in date order" do
      create(:roadmap_item, church: church, lane: "major_event", title: "Christmas Eve", starts_on: Date.new(2026, 12, 24), ends_on: Date.new(2026, 12, 24))
      create(:roadmap_item, church: church, lane: "major_event", title: "Into 2027", starts_on: Date.new(2026, 12, 27), ends_on: Date.new(2027, 1, 10))
      create(:roadmap_item, church: church, lane: "major_event", title: "Next year", starts_on: Date.new(2027, 3, 1), ends_on: Date.new(2027, 3, 1))
      create(:roadmap_item, lane: "major_event", title: "Another church's event", starts_on: Date.new(2026, 5, 1), ends_on: Date.new(2026, 5, 1))
      create(:sermon_series, church: church, title: "Undated", starts_on: nil, ends_on: nil)

      get "/api/v1/roadmap", headers: auth_headers(marcus.account), params: { year: 2027 }

      expect(json["lanes"][1]["items"].map { _1["title"] }).to eq(["Into 2027", "Next year"])
      expect(json["lanes"][0]["items"]).to eq([])

      get "/api/v1/roadmap", headers: auth_headers(marcus.account), params: { year: 2026 }

      expect(json["lanes"][0]["items"].map { _1["title"] }).to eq(["Rooted"])
      expect(json["lanes"][1]["items"].map { _1["title"] }).to eq(["Easter Sunday", "Christmas Eve", "Into 2027"])
    end

    it "defaults to the church's current year and tells admins they can edit" do
      travel_to(Time.utc(2026, 11, 23, 15)) do
        get "/api/v1/roadmap", headers: auth_headers(pastor.account)
      end

      expect(json["year"]).to eq(2026)
      expect(json["lanes"][1]["items"].sole["can_edit"]).to be(true)
      expect(json["lanes"][0]["items"].sole["can_edit"]).to be(true)
    end
  end

  describe "GET /api/v1/roadmap_items/:id" do
    it "shows the item with its attached docs, newest first" do
      old = create(:attachment, attachable: easter, title: "Easter run-of-show", url: "https://docs.google.com/document/d/6pqr/edit",
                                owner_membership: marcus, tags: ["production"], updated_at: 2.days.ago)
      sheet = create(:attachment, attachable: easter, title: "Baptism list", url: "https://docs.google.com/spreadsheets/d/7stu/edit",
                                  owner_membership: elena)

      get "/api/v1/roadmap_items/#{easter.id}", headers: auth_headers(marcus.account)

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => easter.id, "title" => "Easter Sunday", "attachments_count" => 2)
      expect(json["attachments"].map { _1["id"] }).to eq([sheet.id, old.id])
      expect(json["attachments"].last).to include(
        "title" => "Easter run-of-show", "url" => "https://docs.google.com/document/d/6pqr/edit", "kind" => "doc",
        "owner" => person(marcus, "Marcus Reyes", "Exec Pastor"), "tags" => ["production"], "can_edit" => true,
      )
      expect(json["attachments"].first).to include("kind" => "sheet", "can_edit" => false)
    end

    it "doesn't show another church's item" do
      other = create(:roadmap_item)

      get "/api/v1/roadmap_items/#{other.id}", headers: auth_headers(marcus.account)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/roadmap_items" do
    it "lets an admin add an item to a lane, naming the move it advances" do
      post "/api/v1/roadmap_items", headers: auth_headers(pastor.account),
                                    params: { lane: "ministry_initiative", title: "Kids & Youth Camps", starts_on: "2026-07-06",
                                              ends_on: "2026-07-17", color: "sky", owner_membership_id: marcus.id, move_id: sundays.id }

      expect(response).to have_http_status(:created)
      expect(json).to include("kind" => "roadmap_item", "lane" => "ministry_initiative", "title" => "Kids & Youth Camps",
                              "owner" => person(marcus, "Marcus Reyes", "Exec Pastor"), "can_edit" => true)
      # The move's pillar comes with it.
      expect(json["advances"]["pillar"]["id"]).to eq(reach.id)
    end

    it "answers 422 for the series lane (series come from the Sermons screen), bad colors and backwards dates" do
      post "/api/v1/roadmap_items", headers: auth_headers(pastor.account),
                                    params: { lane: "sermon_series", title: "x", starts_on: "2026-07-06", ends_on: "2026-07-01", color: "neon" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"].keys).to include("lane", "color", "ends_on")
    end

    it "answers 422 for a move from another pillar, or another church" do
      post "/api/v1/roadmap_items", headers: auth_headers(pastor.account),
                                    params: { lane: "outreach", title: "x", starts_on: "2026-07-06", ends_on: "2026-07-06",
                                              pillar_id: disciple.id, move_id: sundays.id }
      expect(json["errors"]).to have_key("move")

      other_move = create(:move)
      post "/api/v1/roadmap_items", headers: auth_headers(pastor.account),
                                    params: { lane: "outreach", title: "x", starts_on: "2026-07-06", ends_on: "2026-07-06", move_id: other_move.id }
      expect(json["errors"]).to have_key("move")
    end

    it "is admin only" do
      post "/api/v1/roadmap_items", headers: auth_headers(marcus.account),
                                    params: { lane: "outreach", title: "x", starts_on: "2026-07-06", ends_on: "2026-07-06" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH and DELETE /api/v1/roadmap_items/:id" do
    it "lets an admin move an item and clear what it advances, then remove it with its docs" do
      create(:attachment, attachable: easter, owner_membership: marcus)

      patch "/api/v1/roadmap_items/#{easter.id}", headers: auth_headers(pastor.account),
                                                  params: { starts_on: "2026-04-12", ends_on: "2026-04-12", move_id: "", pillar_id: "" }

      expect(response).to have_http_status(:ok)
      expect(json).to include("starts_on" => "2026-04-12", "advances" => nil)

      delete "/api/v1/roadmap_items/#{easter.id}", headers: auth_headers(pastor.account)

      expect(response).to have_http_status(:no_content)
      expect(Cayado::RoadmapItem.exists?(easter.id)).to be(false)
      expect(Cayado::Attachment.count).to eq(0)
    end

    it "is admin only" do
      patch "/api/v1/roadmap_items/#{easter.id}", headers: auth_headers(elena.account), params: { title: "Mine" }
      expect(response).to have_http_status(:forbidden)

      delete "/api/v1/roadmap_items/#{easter.id}", headers: auth_headers(elena.account)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "attachments" do
    it "lets anyone on staff attach a doc to an item or a series, the kind read from the link" do
      post "/api/v1/roadmap_items/#{easter.id}/attachments", headers: auth_headers(marcus.account),
                                                             params: { title: "Run-of-show", url: "https://docs.google.com/document/d/6pqr/edit", tags: ["production"] }

      expect(response).to have_http_status(:created)
      expect(json).to include("title" => "Run-of-show", "kind" => "doc", "tags" => ["production"],
                              "owner" => person(marcus, "Marcus Reyes", "Exec Pastor"), "can_edit" => true)

      post "/api/v1/sermon_series/#{rooted.id}/attachments", headers: auth_headers(elena.account),
                                                             params: { title: "Worship set", url: "https://docs.google.com/spreadsheets/d/4jkl/edit" }
      expect(json["kind"]).to eq("sheet")

      post "/api/v1/sermon_series/#{rooted.id}/attachments", headers: auth_headers(elena.account),
                                                             params: { title: "Slide kit", url: "https://docs.google.com/presentation/d/5mno/edit" }
      expect(json["kind"]).to eq("slide")

      post "/api/v1/sermon_series/#{rooted.id}/attachments", headers: auth_headers(elena.account),
                                                             params: { title: "Folder", url: "https://drive.google.com/drive/folders/abc" }
      expect(json["kind"]).to eq("folder")

      get "/api/v1/sermon_series/#{rooted.id}/attachments", headers: auth_headers(marcus.account)
      expect(json["attachments"].map { _1["title"] }).to eq(["Folder", "Slide kit", "Worship set"])

      get "/api/v1/roadmap_items/#{easter.id}/attachments", headers: auth_headers(marcus.account)
      expect(json["attachments"].map { _1["title"] }).to eq(["Run-of-show"])
    end

    it "takes an explicit kind for other links, and answers 422 for a link that isn't http(s) or an unknown kind" do
      post "/api/v1/roadmap_items/#{easter.id}/attachments", headers: auth_headers(marcus.account),
                                                             params: { title: "Notion page", url: "https://notion.so/x", kind: "doc" }
      expect(json["kind"]).to eq("doc")

      post "/api/v1/roadmap_items/#{easter.id}/attachments", headers: auth_headers(marcus.account),
                                                             params: { title: "Bad", url: "javascript:alert(1)", kind: "zip" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"].keys).to include("url", "kind")
    end

    it "is edited and removed by whoever attached it, or an admin" do
      doc = create(:attachment, attachable: easter, owner_membership: marcus, title: "Draft")

      patch "/api/v1/attachments/#{doc.id}", headers: auth_headers(elena.account), params: { title: "Mine" }
      expect(response).to have_http_status(:forbidden)

      patch "/api/v1/attachments/#{doc.id}", headers: auth_headers(marcus.account), params: { title: "Final", tags: ["a", "b"] }
      expect(response).to have_http_status(:ok)
      expect(json).to include("title" => "Final", "tags" => ["a", "b"])

      delete "/api/v1/attachments/#{doc.id}", headers: auth_headers(elena.account)
      expect(response).to have_http_status(:forbidden)

      delete "/api/v1/attachments/#{doc.id}", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(Cayado::Attachment.exists?(doc.id)).to be(false)
    end

    it "doesn't reach another church's docs, items or series" do
      other_item = create(:roadmap_item)
      other_doc = create(:attachment, attachable: other_item)

      post "/api/v1/roadmap_items/#{other_item.id}/attachments", headers: auth_headers(pastor.account),
                                                                 params: { title: "x", url: "https://example.com" }
      expect(response).to have_http_status(:not_found)

      delete "/api/v1/attachments/#{other_doc.id}", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:not_found)
    end

    it "go when their series goes" do
      create(:attachment, attachable: rooted)

      rooted.destroy!

      expect(Cayado::Attachment.count).to eq(0)
    end
  end
end
