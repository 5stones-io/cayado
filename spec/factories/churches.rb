FactoryBot.define do
  factory :church do
    sequence(:slug) { |n| "church#{n}" }
    sequence(:name) { |n| "Church #{n}" }
    status { "approved" }
  end
end
