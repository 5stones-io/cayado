FactoryBot.define do
  factory :vision, class: "Cayado::Vision" do
    association :church
    title { "2026–2030 Vision" }
    start_year { 2026 }
    end_year { 2030 }
  end

  factory :pillar, class: "Cayado::Pillar" do
    association :vision
    sequence(:title) { |n| "Pillar #{n}" }
    tone { "ink" }
  end

  factory :move, class: "Cayado::Move" do
    association :pillar
    sequence(:text) { |n| "Move #{n}" }
  end

  factory :horizon_year, class: "Cayado::HorizonYear" do
    association :vision
    sequence(:year) { |n| 2026 + n }
    headline { "Year of Foundations" }
  end

  factory :ministry, class: "Cayado::Ministry" do
    association :church
    sequence(:key) { |n| "ministry-#{n}" }
    sequence(:name) { |n| "Ministry #{n}" }
  end

  factory :sermon_series, class: "Cayado::SermonSeries" do
    association :church
    sequence(:title) { |n| "Series #{n}" }
    starts_on { Date.new(2026, 2, 8) }
    ends_on { Date.new(2026, 3, 15) }
  end

  factory :sermon_week, class: "Cayado::SermonWeek" do
    association :sermon_series
    sequence(:position) { |n| n }
    preached_on { Date.new(2026, 2, 8) }
    sequence(:title) { |n| "Week #{n}" }
  end

  factory :alignment_plan, class: "Cayado::AlignmentPlan" do
    association :sermon_week
    ministry { association :ministry, church: sermon_week.sermon_series.church }
    body { "A plan" }
  end

  factory :comment, class: "Cayado::Comment" do
    association :sermon_week
    membership { association :membership, church: sermon_week.sermon_series.church }
    body { "A comment" }
  end
end
