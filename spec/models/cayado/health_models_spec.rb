require "rails_helper"

RSpec.describe "Health models" do
  describe Cayado::WeeklyMetric do
    it "is one row per church per Sunday" do
      church = create(:church)
      create(:weekly_metric, church: church, week_of: Date.new(2026, 2, 22))

      expect(build(:weekly_metric, church: church, week_of: Date.new(2026, 2, 22))).not_to be_valid
      expect(build(:weekly_metric, church: create(:church), week_of: Date.new(2026, 2, 22))).to be_valid
    end

    it "is dated by the Sunday" do
      metric = build(:weekly_metric, week_of: Date.new(2026, 2, 23))

      expect(metric).not_to be_valid
      expect(metric.errors[:week_of]).to eq(["must be a Sunday"])
    end

    it "takes no negative numbers, but a number can be unknown" do
      expect(build(:weekly_metric, attendance: -1)).not_to be_valid
      expect(build(:weekly_metric, giving_cents: -1)).not_to be_valid
      expect(build(:weekly_metric, attendance: nil, first_time_guests: nil, giving_cents: nil)).to be_valid
    end

    it "keeps the by-ministry split as named counts" do
      expect(build(:weekly_metric, by_ministry: [{ "name" => "Adults", "value" => 612 }])).to be_valid
      expect(build(:weekly_metric, by_ministry: [{ "name" => "", "value" => 612 }])).not_to be_valid
      expect(build(:weekly_metric, by_ministry: [{ "name" => "Kids", "value" => -3 }])).not_to be_valid
      expect(build(:weekly_metric, by_ministry: { "Kids" => 3 })).not_to be_valid
    end

    it "only knows manual and Planning Center as sources" do
      expect(build(:weekly_metric, source: "pco")).to be_valid
      expect(build(:weekly_metric, source: "scribe")).not_to be_valid
    end
  end

  describe Cayado::Budget do
    it "is one monthly figure per church per year" do
      church = create(:church)
      create(:budget, church: church, year: 2026)

      expect(build(:budget, church: church, year: 2026)).not_to be_valid
      expect(build(:budget, church: church, year: 2027)).to be_valid
      expect(build(:budget, monthly_cents: 0)).not_to be_valid
    end

    it "spreads the month over weeks for a single Sunday's comparison" do
      expect(build(:budget, monthly_cents: 117_000_00).weekly_cents).to eq(27_000_00)
    end
  end

  describe Cayado::CongregationSnapshot do
    it "keeps life stages as percentages and season markers as counts" do
      snapshot = build(:congregation_snapshot,
                       life_stages: [{ "label" => "Young families with kids", "pct" => 32 }],
                       season_markers: [{ "label" => "births", "count" => 7 }])
      expect(snapshot).to be_valid

      expect(build(:congregation_snapshot, life_stages: [{ "label" => "Seniors", "pct" => 120 }])).not_to be_valid
      expect(build(:congregation_snapshot, season_markers: [{ "label" => "", "count" => 3 }])).not_to be_valid
      expect(build(:congregation_snapshot, households: -1)).not_to be_valid
    end

    it "lets go of its pinned weeks when deleted" do
      snapshot = create(:congregation_snapshot)
      week = create(:sermon_week, sermon_series: create(:sermon_series, church: snapshot.church),
                                  congregation_snapshot: snapshot)

      snapshot.destroy!

      expect(week.reload.congregation_snapshot).to be_nil
    end

    it "only pins to a week at its own church" do
      snapshot = create(:congregation_snapshot)
      week = build(:sermon_week, sermon_series: create(:sermon_series), congregation_snapshot: snapshot)

      expect(week).not_to be_valid
      expect(week.errors[:congregation_snapshot]).to be_present
    end
  end
end
