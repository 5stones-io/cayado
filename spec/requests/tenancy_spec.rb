require "rails_helper"

RSpec.describe "Which church a request is for", type: :request do
  let(:account) { create(:account) }

  def me = get("/api/v1/me", headers: auth_headers(account))

  it "is the church at {slug}.cayado.cloud" do
    church = create(:church, slug: "jcc")
    create(:church) # more than one, so no single-church fallback
    create(:membership, account: account, church: church)

    use_tenant_host!(church)
    me

    expect(response).to have_http_status(:ok)
    expect(json.dig("church", "slug")).to eq("jcc")
  end

  it "is the church whose verified custom domain it is" do
    church = create(:church, slug: "jcc")
    create(:church)
    create(:custom_domain, :verified, church: church, hostname: "plan.jcc-church.org")
    create(:membership, account: account, church: church)

    host! "Plan.JCC-church.org"
    me

    expect(response).to have_http_status(:ok)
  end

  it "isn't a church on an unverified custom domain" do
    church = create(:church, slug: "jcc")
    create(:church)
    create(:custom_domain, church: church, hostname: "plan.jcc-church.org")
    create(:membership, account: account, church: church)

    host! "plan.jcc-church.org"
    me

    expect(response).to have_http_status(:not_found)
  end

  it "is a 404 for an address that's no church when there are several" do
    create_list(:church, 2)
    host! "unknown.example.com"
    me

    expect(response).to have_http_status(:not_found)
    expect(json["code"]).to eq("not_found")
  end

  it "is the only church on a self-hosted install, whatever the address" do
    church = create(:church)
    create(:membership, account: account, church: church)

    host! "10.0.0.5"
    me

    expect(response).to have_http_status(:ok)
  end

  it "is 403 for someone signed in who isn't on that church's team" do
    mine = create(:church, slug: "mine")
    other = create(:church, slug: "other")
    create(:membership, account: account, church: mine)

    use_tenant_host!(other)
    me

    expect(response).to have_http_status(:forbidden)
    expect(json["code"]).to eq("not_a_member")
  end

  it "is 401 without a sign-in" do
    church = create(:church)
    use_tenant_host!(church)
    get "/api/v1/me"

    expect(response).to have_http_status(:unauthorized)
  end

  it "is 401 for a session that hasn't entered an authenticator code" do
    church = create(:church)
    create(:membership, account: account, church: church)
    use_tenant_host!(church)
    get "/api/v1/me", headers: { "Authorization" => "Bearer #{jwt_for(account, authenticated_by: ["password"])}" }

    expect(response).to have_http_status(:unauthorized)
  end
end
