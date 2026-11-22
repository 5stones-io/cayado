require "rails_helper"

RSpec.describe Account do
  it "stores the email lowercased and trimmed" do
    expect(create(:account, email: "  Maya@Example.COM ").email).to eq("maya@example.com")
  end

  it "has a name only when one was given" do
    expect(build(:account).name).to be_nil
    expect(build(:account, first_name: "Maya").name).to eq("Maya")
    expect(build(:account, first_name: "Maya", last_name: "Okafor").name).to eq("Maya Okafor")
  end
end

RSpec.describe Church do
  it "takes only lowercase slugs with hyphens inside" do
    expect(build(:church, slug: "grace-church")).to be_valid
    %w[Grace -grace grace- grace_church].each do |slug|
      expect(build(:church, slug: slug)).not_to be_valid
    end
  end

  it "takes only real time zones" do
    expect(build(:church, timezone: "America/Denver")).to be_valid
    expect(build(:church, timezone: "Mars/Olympus")).not_to be_valid
  end

  it "works out today in its own time zone" do
    church = build(:church, timezone: "America/Los_Angeles")
    travel_to(Time.utc(2026, 11, 23, 3, 0)) do
      expect(church.today).to eq(Date.new(2026, 11, 22))
    end
  end

  it "shows its display name when it has one" do
    expect(build(:church, name: "Jubilee Christian Center").brand_name).to eq("Jubilee Christian Center")
    expect(build(:church, name: "Jubilee Christian Center", display_name: "Jubilee").brand_name).to eq("Jubilee")
  end
end

RSpec.describe Membership do
  it "has one membership per account per church" do
    existing = create(:membership)

    expect(build(:membership, account: existing.account, church: existing.church)).not_to be_valid
  end

  it "takes only known roles" do
    expect(build(:membership, role: "family")).not_to be_valid
    expect(build(:membership, :owner).admin_or_owner?).to be(true)
    expect(build(:membership).admin_or_owner?).to be(false)
  end
end

RSpec.describe CustomDomain do
  it "gets a verification token and a lowercase hostname" do
    domain = create(:custom_domain, hostname: "Plan.Example.org")

    expect(domain.hostname).to eq("plan.example.org")
    expect(domain.verification_token).to match(/\A\h{32}\z/)
    expect(domain).not_to be_verified
    domain.verify!
    expect(domain).to be_verified
  end
end
