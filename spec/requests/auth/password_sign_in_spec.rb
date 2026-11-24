require "rails_helper"

# Password + authenticator sign-in, end to end through Rodauth's JSON
# routes, the way the mobile app and web call them. Every Cayado account
# must use two-step.
RSpec.describe "Password and two-step sign-in", type: :request do
  let(:church) { create(:church, slug: "gracechurch") }
  let(:password) { "correct horse battery" }

  let(:sent_codes) { Hash.new { |h, k| h[k] = [] } }

  before do
    allow(AuthEmail).to receive(:password_code) { |email:, code:, **| sent_codes[email] << code }
  end

  def post_json(path, body = nil, token: nil, **fields)
    body ||= fields
    headers = { "Content-Type" => "application/json", "Accept" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token
    post path, params: body.to_json, headers: headers
  end

  def me(token)
    use_tenant_host!(church)
    get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }
    response.status
  end

  def emailed_code(email) = sent_codes[email].last

  def set_password!(email)
    post_json "/auth/password-code-request", email: email
    post_json "/auth/password-code-set", email: email, code: emailed_code(email), password: password
    expect(response).to have_http_status(:ok)
    json
  end

  # The same TOTP code can't be used twice in one 30-second window; move
  # the last use back so a spec can set up and then sign in straight away.
  def forget_last_otp_use!
    ActiveRecord::Base.connection.execute("UPDATE account_otp_keys SET last_use = NOW() - INTERVAL '5 minutes'")
  end

  # Sets up an authenticator for whoever `token` belongs to; returns the
  # secret, the recovery codes and the full session token.
  def set_up_authenticator!(token)
    post_json "/auth/otp-setup", {}, token: token
    secret, raw = json.values_at("otp_secret", "otp_raw_secret")
    post_json "/auth/otp-setup", { otp_secret: secret, otp_raw_secret: raw, otp: ROTP::TOTP.new(secret).now }, token: token
    expect(response).to have_http_status(:ok)
    forget_last_otp_use!
    [secret, json["recovery_codes"], json["token"]]
  end

  describe "POST /auth/password-code-request" do
    it "creates the account and emails a 6-digit code with a set-password link" do
      post_json "/auth/password-code-request", email: " New@Example.com "

      expect(response).to have_http_status(:ok)
      account = Account.find_by!(email: "new@example.com")
      expect(AuthEmail).to have_received(:password_code).with(
        email: "new@example.com", code: a_string_matching(/\A\d{6}\z/),
        link: a_string_matching(%r{/set-password\?email=new%40example.com&code=\d{6}\z})
      )
      expect(AccountPasswordCode.exists?(account.id)).to be(true)
    end

    it "answers the same for an existing account" do
      create(:account, email: "known@example.com")
      post_json "/auth/password-code-request", email: "unknown@example.com"
      unknown = [response.status, json]
      post_json "/auth/password-code-request", email: "known@example.com"

      expect([response.status, json]).to eq(unknown)
    end

    it "doesn't email a second code within a minute" do
      2.times { post_json "/auth/password-code-request", email: "twice@example.com" }

      expect(response).to have_http_status(:ok)
      expect(AuthEmail).to have_received(:password_code).once
    end

    it "rejects something that isn't an email" do
      post_json "/auth/password-code-request", email: "not an email"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Account.where(email: "not an email")).to be_empty
    end
  end

  describe "POST /auth/password-code-set" do
    let!(:account) { create(:account, email: "pastor@example.com") }

    before do
      create(:membership, account: account, church: church)
      post_json "/auth/password-code-request", email: "pastor@example.com"
    end

    it "sets the password and signs in, still needing an authenticator" do
      post_json "/auth/password-code-set", email: "pastor@example.com", code: emailed_code("pastor@example.com"), password: password

      expect(response).to have_http_status(:ok)
      expect(json["two_step"]).to eq("setup")
      expect(me(json["token"])).to eq(401)
      expect(AccountPasswordCode.exists?(account.id)).to be(false)
    end

    it "rejects a wrong code, and kills the code after 5 wrong tries" do
      real = emailed_code("pastor@example.com")
      wrong = real == "000000" ? "111111" : "000000"
      5.times { post_json "/auth/password-code-set", email: "pastor@example.com", code: wrong, password: password }
      expect(response).to have_http_status(:unauthorized)
      expect(json["error"]).to eq("That code is wrong or has expired.")

      post_json "/auth/password-code-set", email: "pastor@example.com", code: real, password: password
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired code" do
      AccountPasswordCode.where(id: account.id).update_all(deadline: 1.minute.ago)
      post_json "/auth/password-code-set", email: "pastor@example.com", code: emailed_code("pastor@example.com"), password: password

      expect(response).to have_http_status(:unauthorized)
    end

    it "says why a password is too short, and keeps the code usable" do
      code = emailed_code("pastor@example.com")
      post_json "/auth/password-code-set", email: "pastor@example.com", code: code, password: "short"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to eq("Choose a different password: use at least 12 characters.")

      post_json "/auth/password-code-set", email: "pastor@example.com", code: code, password: password
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /auth/login" do
    let!(:account) { create(:account, email: "pastor@example.com") }

    before do
      create(:membership, account: account, church: church)
      set_password!("pastor@example.com")
    end

    it "gives one answer for a wrong password and an unknown email" do
      post_json "/auth/login", email: "pastor@example.com", password: "wrong password!"
      wrong = [response.status, json["error"]]
      post_json "/auth/login", email: "nobody@example.com", password: "wrong password!"

      expect(wrong).to eq([401, "Email or password is incorrect."])
      expect([response.status, json["error"]]).to eq(wrong)
      expect(json["field-error"]).to eq(["password", "Email or password is incorrect."])
    end

    it "locks out after 10 wrong passwords until the password is set again" do
      10.times { post_json "/auth/login", email: "pastor@example.com", password: "wrong password!" }
      post_json "/auth/login", email: "pastor@example.com", password: password
      expect(response).to have_http_status(:forbidden)
      expect(json["error"]).to include("Set up or reset password")

      travel_to(2.minutes.from_now) { set_password!("pastor@example.com") }
      post_json "/auth/login", email: "pastor@example.com", password: password
      expect(response).to have_http_status(:ok)
    end

    it "doesn't create an account for an unknown email" do
      post_json "/auth/login", email: "nobody@example.com", password: password

      expect(Account.where(email: "nobody@example.com")).to be_empty
    end

    it "must set up an authenticator before the session works, even as a member" do
      post_json "/auth/login", email: "Pastor@Example.com", password: password
      expect(response).to have_http_status(:ok)
      expect(json["two_step"]).to eq("setup")
      partial = json["token"]
      expect(me(partial)).to eq(401)
      decoded, = JWT.decode(partial, Rails.application.secret_key_base, true, algorithm: "HS256")
      expect(decoded["exp"]).to be <= 15.minutes.from_now.to_i

      post_json "/auth/otp-setup", {}, token: partial
      expect(json).to include("otp_secret", "otp_raw_secret")
      expect(json["otpauth_url"]).to start_with("otpauth://totp/Cayado:pastor%40example.com?secret=")
      expect(json["qr_svg"]).to start_with("<svg")

      post_json "/auth/otp-setup", json.slice("otp_secret", "otp_raw_secret").merge(otp: "000000"), token: partial
      expect(json["error"]).to eq("That code didn't work. Check your authenticator app and try again.")

      _secret, codes, full = set_up_authenticator!(partial)
      expect(codes.size).to eq(10)
      expect(codes).to all(match(/\A[a-z2-9]{4}-[a-z2-9]{4}-[a-z2-9]{4}\z/))
      expect(me(full)).to eq(200)
    end

    context "with an authenticator set up" do
      let!(:secret_and_codes) do
        post_json "/auth/login", email: "pastor@example.com", password: password
        set_up_authenticator!(json["token"])
      end

      it "asks for the code after the password" do
        post_json "/auth/login", email: "pastor@example.com", password: password
        expect(json["two_step"]).to eq("code")
        partial = json["token"]
        expect(me(partial)).to eq(401)

        post_json "/auth/otp-auth", { otp: "000000" }, token: partial
        expect(response).to have_http_status(:unauthorized)
        # Shown as-is on the sign-in screen.
        expect(json["error"]).to eq("That code didn't work. Check your authenticator app and try again.")

        post_json "/auth/otp-auth", { otp: ROTP::TOTP.new(secret_and_codes[0]).now }, token: partial
        expect(response).to have_http_status(:ok)
        expect(json["two_step"]).to be_nil
        expect(me(json["token"])).to eq(200)
      end

      it "takes a recovery code however it's typed, once" do
        code = secret_and_codes[1].first
        post_json "/auth/login", email: "pastor@example.com", password: password
        partial = json["token"]

        post_json "/auth/recovery-auth", { "recovery-code" => code.upcase.delete("-") }, token: partial
        expect(response).to have_http_status(:ok)
        expect(me(json["token"])).to eq(200)

        post_json "/auth/login", email: "pastor@example.com", password: password
        post_json "/auth/recovery-auth", { "recovery-code" => code }, token: json["token"]
        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq("That recovery code didn't work. Each one works only once.")
      end

      it "can't turn two-step off" do
        post_json "/auth/otp-disable", {}, token: secret_and_codes[2]

        expect(response).to have_http_status(:forbidden)
        expect(ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM account_otp_keys WHERE id = #{account.id}")).to eq(1)
      end

      it "replaces every recovery code when asked for new ones" do
        post_json "/auth/recovery-codes", { add: "1" }, token: secret_and_codes[2]

        expect(response).to have_http_status(:ok)
        expect(json["codes"].size).to eq(10)
        expect(json["codes"] & secret_and_codes[1]).to be_empty
      end
    end
  end

  describe "GET /api/v1/two_step" do
    let!(:account) { create(:account, email: "pastor@example.com") }

    before do
      create(:membership, account: account, church: church)
      set_password!("pastor@example.com")
    end

    def two_step(token)
      use_tenant_host!(church)
      get "/api/v1/two_step", headers: { "Authorization" => "Bearer #{token}" }
      json
    end

    it "says it's on and required, and how many codes are left" do
      post_json "/auth/login", email: "pastor@example.com", password: password
      _secret, codes, full = set_up_authenticator!(json["token"])
      expect(two_step(full)).to eq("enabled" => true, "required" => true, "recovery_codes_left" => 10)

      post_json "/auth/login", email: "pastor@example.com", password: password
      post_json "/auth/recovery-auth", { "recovery-code" => codes.first }, token: json["token"]
      expect(two_step(full)).to include("recovery_codes_left" => 9)
    end
  end
end
