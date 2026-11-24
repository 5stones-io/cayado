require "rails_helper"

RSpec.describe "GET /api/v1/me", type: :request do
  let(:church) { create(:church, slug: "jcc", name: "Jubilee Christian Center", display_name: "Jubilee", timezone: "America/New_York", city: "Fairfax", state: "VA") }
  let(:account) { create(:account, email: "maya@example.com", first_name: "Maya", last_name: "Okafor") }

  before { use_tenant_host!(church) }

  it "says who's signed in and what they are at this church" do
    create(:membership, :admin, account: account, church: church, title: "Lead Pastor")

    get "/api/v1/me", headers: auth_headers(account)

    expect(response).to have_http_status(:ok)
    expect(json).to eq(
      "id" => account.id, "email" => "maya@example.com", "first_name" => "Maya", "last_name" => "Okafor",
      "name" => "Maya Okafor", "role" => "admin", "title" => "Lead Pastor", "admin" => true,
      "church" => { "name" => "Jubilee", "slug" => "jcc", "timezone" => "America/New_York", "location" => "Fairfax, VA" }
    )
  end

  it "isn't admin for a member, and falls back to the default time zone" do
    church.update!(timezone: nil)
    create(:membership, account: account, church: church, title: "Kids Pastor")

    get "/api/v1/me", headers: auth_headers(account)

    expect(json).to include("role" => "member", "admin" => false)
    expect(json.dig("church", "timezone")).to eq("America/Chicago")
  end

  it "gives as much of the church's location as it has" do
    create(:membership, account: account, church: church)

    church.update!(state: nil)
    get "/api/v1/me", headers: auth_headers(account)
    expect(json.dig("church", "location")).to eq("Fairfax")

    church.update!(city: nil)
    get "/api/v1/me", headers: auth_headers(account)
    expect(json.dig("church", "location")).to be_nil
  end
end

RSpec.describe "GET /api/v1/tenant", type: :request do
  it "names the church at this address, without a sign-in" do
    church = create(:church, slug: "jcc", name: "Jubilee Christian Center")
    create(:church)
    use_tenant_host!(church)

    get "/api/v1/tenant"

    expect(response).to have_http_status(:ok)
    expect(json).to eq("name" => "Jubilee Christian Center", "hostname" => "localhost:3000")
  end

  it "gives the verified primary custom domain as its address" do
    church = create(:church, slug: "jcc")
    create(:custom_domain, :verified, church: church, hostname: "plan.jcc.org", primary: true)
    use_tenant_host!(church)

    get "/api/v1/tenant"

    expect(json["hostname"]).to eq("plan.jcc.org")
  end

  it "is a 404 for an address that isn't a church" do
    create_list(:church, 2)
    host! "nope.cayado.cloud"

    get "/api/v1/tenant"

    expect(response).to have_http_status(:not_found)
  end
end
