require "rails_helper"

RSpec.describe "Planning models" do
  describe Cayado::Ministry do
    it "gives every new church Kids, Youth, Small Groups and Worship, in that order" do
      church = create(:church)

      expect(church.ministries.order(:position).pluck(:key, :name))
        .to eq([["kids", "Kids"], ["youth", "Youth"], ["small-groups", "Small Groups"], ["worship", "Worship"]])
    end

    it "keeps keys unique per church, not across churches" do
      church = create(:church)
      expect(build(:ministry, church: church, key: "kids")).not_to be_valid
      expect(build(:ministry, church: create(:church), key: "music")).to be_valid
    end

    it "can't be led by someone on another church's staff" do
      church = create(:church)
      outsider = create(:membership)
      ministry = church.ministries.find_by!(key: "kids")

      ministry.lead_membership = outsider
      expect(ministry).not_to be_valid
    end
  end

  describe Cayado::Pillar do
    it "only takes the tones the design has" do
      expect(build(:pillar, tone: "sage")).to be_valid
      expect(build(:pillar, tone: "purple")).not_to be_valid
    end
  end

  describe Cayado::Vision do
    it "is one per church and its years run forward" do
      vision = create(:vision)
      expect(build(:vision, church: vision.church)).not_to be_valid
      expect(build(:vision, start_year: 2030, end_year: 2026)).not_to be_valid
    end
  end

  describe Cayado::SermonSeries do
    it "can only advance a move from its own church's vision" do
      series = create(:sermon_series)
      other_move = create(:move)

      series.move = other_move
      expect(series).not_to be_valid

      series.move = create(:move, pillar: create(:pillar, vision: create(:vision, church: series.church)))
      expect(series).to be_valid
    end

    it "counts planned slots against every ministry on every week" do
      series = create(:sermon_series)
      kids, youth = series.church.ministries.where(key: %w[kids youth]).order(:position)
      week1 = create(:sermon_week, sermon_series: series, position: 1)
      create(:sermon_week, sermon_series: series, position: 2)
      create(:alignment_plan, sermon_week: week1, ministry: kids)
      create(:alignment_plan, sermon_week: week1, ministry: youth)

      expect(series.alignment).to eq(planned: 2, total: 8)
    end
  end

  describe Cayado::AlignmentPlan do
    it "is one per ministry per week, and only for its church's ministries" do
      plan = create(:alignment_plan)
      expect(build(:alignment_plan, sermon_week: plan.sermon_week, ministry: plan.ministry)).not_to be_valid
      expect(build(:alignment_plan, sermon_week: plan.sermon_week, ministry: create(:ministry))).not_to be_valid
    end
  end

  describe Cayado::Comment do
    it "outlives its author leaving the staff" do
      comment = create(:comment)

      comment.membership.destroy!

      expect(comment.reload.membership).to be_nil
      expect(comment.body).to eq("A comment")
    end
  end

  describe Cayado::SermonWeek do
    it "finds the week being preached this coming Sunday (or today, if it's Sunday)" do
      church = create(:church)
      series = create(:sermon_series, church: church)
      last = create(:sermon_week, sermon_series: series, preached_on: Date.new(2026, 2, 22))
      coming = create(:sermon_week, sermon_series: series, preached_on: Date.new(2026, 3, 1))

      expect(Cayado::SermonWeek.upcoming_for(church, on: Date.new(2026, 2, 23))).to eq(coming)
      expect(Cayado::SermonWeek.upcoming_for(church, on: Date.new(2026, 2, 22))).to eq(last)
      expect(Cayado::SermonWeek.upcoming_for(create(:church), on: Date.new(2026, 2, 22))).to be_nil
    end
  end
end
