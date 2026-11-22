module AuthHelpers
  # A fully signed-in session: password and authenticator code. Every
  # Cayado account must use two-step, so a password-only token answers 401;
  # pass authenticated_by: ["password"] to test that.
  def jwt_for(account, authenticated_by: ["password", "totp"])
    payload = {
      "account_id"       => account.id,
      "authenticated_by" => authenticated_by,
      "email"            => account.email,
      "exp"              => (Time.now + 7_200).to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end

  def auth_headers(account)
    { "Authorization" => "Bearer #{jwt_for(account)}" }
  end

  # The default test host (www.example.com) is no church. This makes later
  # requests in the example arrive on the church's {slug}.cayado.cloud.
  def use_tenant_host!(church)
    host! "#{church.slug}.cayado.cloud"
  end

  def json = JSON.parse(response.body)
end
