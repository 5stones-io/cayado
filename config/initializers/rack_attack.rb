# Rate limits on sign-in, keyed by the email being signed in, not by IP:
# behind a hosting edge the request IP isn't reliably the visitor's.
# Per-account guessing is already capped by Rodauth (lockout after 10 wrong
# passwords, OTP lockout after 5 wrong codes, 5 tries per emailed code);
# these cap how fast one email can be hammered and how many code emails it
# can be sent. Counters live in Rails.cache (the null store in test, so
# specs aren't throttled).
class Rack::Attack
  def self.posted_email(req)
    body = req.body.read
    req.body.rewind
    data = JSON.parse(body) rescue nil
    data["email"].to_s.strip.downcase.presence if data.is_a?(Hash)
  end

  throttle("login/email", limit: 20, period: 5.minutes) do |req|
    posted_email(req) if req.post? && %w[/auth/login /auth/password-code-set].include?(req.path)
  end

  throttle("password-code-request/email", limit: 5, period: 1.hour) do |req|
    posted_email(req) if req.post? && req.path == "/auth/password-code-request"
  end

  self.throttled_responder = lambda do |_request|
    [429, { "content-type" => "application/json" }, [{ error: "Too many tries. Wait a few minutes and try again.", code: "rate_limited" }.to_json]]
  end
end
