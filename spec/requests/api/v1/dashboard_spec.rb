require "rails_helper"

RSpec.describe "Dashboard and weekly numbers", type: :request do
  let(:church) { create(:church, slug: "jcc") }
  let(:pastor) { create(:membership, :admin, church: church) }
  let(:sarah) { create(:membership, church: church) }

  # Monday, Mar 2 2026: the last Sunday is Mar 1.
  around { |example| travel_to(Time.zone.parse("2026-03-02 09:00 America/Chicago")) { example.run } }
  before { use_tenant_host!(church) }

  def metric(on, **attrs) = create(:weekly_metric, church: church, week_of: Date.parse(on), **attrs)

  describe "GET /api/v1/dashboard" do
    it "has a full year of empty weeks and months before any numbers are in" do
      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(response).to have_http_status(:ok)
      expect(json["as_of"]).to eq("2026-03-01")
      expect(json["stats"]).to eq(
        "avg_attendance" => nil, "attendance_trend_pct" => nil,
        "ytd_giving_cents" => 0, "giving_through" => nil, "months_reported" => 0,
        "giving_vs_budget_pct" => nil,
        "first_time_guests_this_month" => 0, "first_time_guests_vs_3mo" => nil
      )
      expect(json["weekly"].size).to eq(52)
      expect(json["weekly"].first).to eq("week_of" => "2025-03-09", "attendance" => nil, "trend" => nil, "label" => nil)
      expect(json["weekly"].last["week_of"]).to eq("2026-03-01")
      expect(json["monthly_giving"].map { _1["month"] }).to eq(
        %w[2025-04 2025-05 2025-06 2025-07 2025-08 2025-09 2025-10 2025-11 2025-12 2026-01 2026-02 2026-03]
      )
      expect(json).to include("by_ministry" => nil, "budget" => nil)
    end

    it "averages the last 13 weeks' attendance against the 13 before" do
      12.times { |i| metric((Date.new(2026, 3, 1) - i.weeks).to_s, attendance: 850) }
      metric("2025-12-07", attendance: nil) # a week with no count doesn't drag the average down
      13.times { |i| metric((Date.new(2025, 11, 30) - i.weeks).to_s, attendance: 800) }

      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(json["stats"]).to include("avg_attendance" => 850, "attendance_trend_pct" => 6.3)
    end

    it "plots each week with a five-week trend and its label" do
      metric("2026-02-01", attendance: 800)
      metric("2026-02-08", attendance: 820)
      metric("2026-02-15", attendance: 840)
      metric("2026-02-22", attendance: 860)
      metric("2026-03-01", attendance: 1180, label: "Easter")

      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(json["weekly"].last(2)).to eq([
        { "week_of" => "2026-02-22", "attendance" => 860, "trend" => 830, "label" => nil },
        { "week_of" => "2026-03-01", "attendance" => 1180, "trend" => 900, "label" => "Easter" },
      ])
    end

    it "totals giving for the year and compares finished months with the budget" do
      create(:budget, church: church, year: 2026, monthly_cents: 100_000_00)
      metric("2025-12-28", giving_cents: 70_000_00)
      metric("2026-01-04", giving_cents: 50_000_00)
      metric("2026-01-11", giving_cents: 60_000_00)
      metric("2026-02-01", giving_cents: 95_000_00)
      metric("2026-03-01", giving_cents: 30_000_00)

      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(json["stats"]).to include(
        "ytd_giving_cents" => 235_000_00, "giving_through" => "2026-03", "months_reported" => 3,
        "giving_vs_budget_pct" => 103 # Jan + Feb: 205k of 200k
      )
      expect(json["budget"]).to eq("year" => 2026, "monthly_cents" => 100_000_00)
      expect(json["monthly_giving"].last(4)).to eq([
        { "month" => "2025-12", "giving_cents" => 70_000_00, "budget_cents" => nil, "status" => nil, "partial" => false },
        { "month" => "2026-01", "giving_cents" => 110_000_00, "budget_cents" => 100_000_00, "status" => "at_or_above", "partial" => false },
        { "month" => "2026-02", "giving_cents" => 95_000_00, "budget_cents" => 100_000_00, "status" => "below", "partial" => false },
        { "month" => "2026-03", "giving_cents" => 30_000_00, "budget_cents" => 100_000_00, "status" => nil, "partial" => true },
      ])
      expect(json["monthly_giving"].first).to include("month" => "2025-04", "giving_cents" => nil)
    end

    it "counts this month's first-time guests against the three months before" do
      metric("2025-11-30", first_time_guests: 99) # four months back: not counted
      metric("2025-12-07", first_time_guests: 30)
      metric("2026-01-04", first_time_guests: 20)
      metric("2026-01-11", first_time_guests: 16)
      metric("2026-02-08", first_time_guests: 33)
      metric("2026-03-01", first_time_guests: 11)

      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(json["stats"]).to include("first_time_guests_this_month" => 11, "first_time_guests_vs_3mo" => -22)
    end

    it "splits the most recent weekend that has one by ministry" do
      metric("2026-02-22", by_ministry: [{ "name" => "Adults", "value" => 600 }])
      metric("2026-03-01", by_ministry: [{ "name" => "Adults", "value" => 612 }, { "name" => "Kids", "value" => 168 }])

      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(json["by_ministry"]).to eq(
        "week_of" => "2026-03-01",
        "rows" => [{ "name" => "Adults", "value" => 612 }, { "name" => "Kids", "value" => 168 }]
      )
    end

    it "only counts this church's numbers" do
      create(:weekly_metric, church: create(:church), week_of: Date.new(2026, 3, 1), attendance: 5000, giving_cents: 1)

      get "/api/v1/dashboard", headers: auth_headers(sarah.account)

      expect(json["stats"]).to include("avg_attendance" => nil, "ytd_giving_cents" => 0)
    end
  end

  describe "weekly numbers (manual entry until Planning Center)" do
    it "lists a year's Sundays for anyone on staff" do
      metric("2025-12-28", attendance: 700)
      metric("2026-01-04", attendance: 810, first_time_guests: 9, giving_cents: 25_000_00, label: "Vision Sunday")

      get "/api/v1/weekly_metrics?year=2026", headers: auth_headers(sarah.account)

      expect(json["weekly_metrics"]).to eq([{
        "week_of" => "2026-01-04", "attendance" => 810, "first_time_guests" => 9,
        "giving_cents" => 25_000_00, "by_ministry" => [], "label" => "Vision Sunday", "source" => "manual",
      }])
    end

    it "lets an admin write a Sunday's numbers, then correct them" do
      put "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(pastor.account),
          params: { attendance: 892, first_time_guests: 11, giving_cents: 28_400_00, label: "Communion",
                    by_ministry: [{ name: "Adults", value: 612 }] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("week_of" => "2026-03-01", "attendance" => 892, "giving_cents" => 28_400_00,
                              "by_ministry" => [{ "name" => "Adults", "value" => 612 }], "source" => "manual")

      put "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(pastor.account), params: { attendance: 900 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("attendance" => 900, "first_time_guests" => 11)
      expect(church.weekly_metrics.count).to eq(1)
    end

    it "marks a Planning Center row manual once someone corrects it" do
      metric("2026-03-01", attendance: 880, source: "pco")

      put "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(pastor.account), params: { attendance: 892 }, as: :json

      expect(json["source"]).to eq("manual")
    end

    it "only takes Sundays and real dates" do
      put "/api/v1/weekly_metrics/2026-03-02", headers: auth_headers(pastor.account), params: { attendance: 1 }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("errors", "week_of")).to eq(["must be a Sunday"])

      put "/api/v1/weekly_metrics/not-a-date", headers: auth_headers(pastor.account), params: { attendance: 1 }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["code"]).to eq("invalid_date")
    end

    it "lets an admin delete a Sunday's numbers" do
      metric("2026-03-01")

      delete "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(church.weekly_metrics).to be_empty

      delete "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:not_found)
    end

    it "sets the year's monthly budget (admin)" do
      put "/api/v1/budgets/2026", headers: auth_headers(pastor.account), params: { monthly_cents: 117_000_00 }, as: :json
      expect(response).to have_http_status(:created)
      expect(json).to eq("year" => 2026, "monthly_cents" => 117_000_00)

      put "/api/v1/budgets/2026", headers: auth_headers(pastor.account), params: { monthly_cents: 120_000_00 }, as: :json
      expect(response).to have_http_status(:ok)

      put "/api/v1/budgets/2026", headers: auth_headers(pastor.account), params: { monthly_cents: 0 }, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      delete "/api/v1/budgets/2026", headers: auth_headers(pastor.account)
      expect(response).to have_http_status(:no_content)
      expect(Cayado::Budget.where(church: church)).to be_empty
    end

    it "keeps writes to admins" do
      put "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(sarah.account), params: { attendance: 1 }, as: :json
      expect(response).to have_http_status(:forbidden)

      delete "/api/v1/weekly_metrics/2026-03-01", headers: auth_headers(sarah.account)
      expect(response).to have_http_status(:forbidden)

      put "/api/v1/budgets/2026", headers: auth_headers(sarah.account), params: { monthly_cents: 1 }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
