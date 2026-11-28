require "rails_helper"

# Status and placeholder-slug helpers, as the spirely gem's Church has them.
# cayado-cloud provisions a church from cayado.io with a "tmp-<uuid>" slug,
# claimed during onboarding, and suspends/reactivates it with billing.
RSpec.describe Church, type: :model do
  describe "#placeholder_slug?" do
    it "is true for a tmp- slug and false for a real one" do
      expect(build(:church, slug: "#{Church::TMP_SLUG_PREFIX}#{SecureRandom.uuid}")).to be_placeholder_slug
      expect(build(:church, slug: "jccag")).not_to be_placeholder_slug
    end
  end

  describe "status" do
    it "answers pending? and suspended?" do
      expect(build(:church, status: "pending")).to be_pending
      expect(build(:church, status: "suspended")).to be_suspended
      expect(build(:church, status: "approved")).not_to be_pending
    end

    it "suspends and approves" do
      church = create(:church)
      church.suspend!
      expect(church.reload).to be_suspended
      church.approve!
      expect(church.reload.status).to eq("approved")
    end
  end
end
