require "sequel/core"
require_relative "../../lib/rodauth/features/password_code"

# Email + password sign-in with an authenticator-app code as a second step,
# copied from spirely-cloud (5ST-70). Every Cayado account is church staff,
# so two-step is required for everyone (TwoStepPolicy). Passwords are set
# and reset with an emailed 6-digit code (the :password_code feature), which
# is also how an invited person gets their first one.
#
# Every successful response from /auth/* includes:
#   token     the session JWT (also in the Authorization header)
#   two_step  nil when fully signed in; "code" when the account still needs
#             to enter an authenticator code (POST /auth/otp-auth or
#             /auth/recovery-auth with this token); "setup" when it has no
#             authenticator yet (POST /auth/otp-setup).
# Until two_step is nil the token is short-lived and every API answers 401.
class CayadoRodauthMain < Rodauth::Rails::Auth
  configure do
    enable :login, :logout, :jwt, :lockout, :otp, :recovery_codes, :password_code

    # Sequel on ActiveRecord's connection pool (no separate DB config).
    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)

    prefix "/auth"
    only_json? true
    convert_token_id_to_integer? true

    jwt_secret { Rails.application.secret_key_base }
    # OTP secrets are stored HMAC'd with this, derived from secret_key_base.
    hmac_secret { Rails.application.key_generator.generate_key("rodauth hmac secret").unpack1("H*") }

    # Signing in again while holding a token just starts a new session.
    already_logged_in {}

    login_param "email"
    password_minimum_length 12
    require_password_confirmation? false

    # One answer for an unknown email and a wrong password, so sign-in
    # doesn't reveal who has an account.
    no_matching_login_message "Email or password is incorrect."
    invalid_password_message "Email or password is incorrect."
    login_error_flash "Email or password is incorrect."

    password_too_short_message { "use at least #{password_minimum_length} characters" }
    password_does_not_meet_requirements_message { "Choose a different password: #{password_requirement_message}." }

    # Lockout after 10 wrong passwords. Unlocking is "Set up or reset
    # password" (password_code_set clears it), not Rodauth's unlock email.
    max_invalid_logins 10
    unlock_account_request_route nil
    unlock_account_route nil
    login_lockout_error_flash "Too many tries. Use \"Set up or reset password\" to sign in."

    otp_issuer "Cayado"
    # Already signed in with a password to get here.
    two_factor_modifications_require_password? false

    recovery_codes_limit 10
    auto_add_recovery_codes? true
    auto_remove_recovery_codes? true

    # Accounts are created by password_code_request (an invite), never by a
    # sign-in attempt.
    account_from_login do |login|
      super(login.to_s.strip.downcase)
    end

    # The JWT is "who" only (email + exp). Church and role come from the
    # Host header and Membership on every request, so a removed membership
    # or a role change applies straight away. A token still waiting on its
    # second step lives 15 minutes; a full one 30 days.
    jwt_session_hash do
      full = account && !two_factor_partially_authenticated? && !two_step_setup_required?
      base = super()
      if account
        base.merge(
          "email" => account[login_column].to_s,
          "exp"   => (full ? 30.days : 15.minutes).from_now.to_i
        )
      else
        base
      end
    end

    # The first answer from /auth/otp-setup carries the new secret; add what
    # the app and web need to show it.
    before_otp_setup_route do
      if json_response[otp_setup_param]
        json_response["otpauth_url"] = otp_provisioning_uri
        json_response["qr_svg"] = otp_qr_code
      end
    end

    # Shown once, right after setup.
    after_otp_setup do
      json_response["recovery_codes"] = recovery_codes
    end

    before_otp_disable_route do
      if TwoStepPolicy.required?(session_value)
        set_response_error_reason_status(:two_step_required, 403)
        set_error_flash "Two-step sign-in is required for every Cayado account."
        return_json_response
      end
    end

    # "New codes" replaces every code, used or not.
    before_add_recovery_codes do
      recovery_codes_remove
      @recovery_codes = nil
    end

    rails_account_model { Account }

    auth_class_eval do
      def authenticated?
        super && !two_step_setup_required?
      end

      # From the database, not the session (JWT) Rodauth caches it in, so a
      # password-only session from before setup doesn't stay signed in.
      def uses_two_factor_authentication?
        return false unless logged_in?
        return true if two_factor_authenticated?

        otp_exists?
      end

      def can_add_recovery_codes?
        true
      end

      # The login error names no field, so it can't tell anyone which
      # emails have accounts.
      def set_field_error(field, message)
        field = password_param if @current_route == :login
        super
      end

      def return_json_response
        if logged_in? && !json_response_error?
          json_response["token"] = session_jwt
          json_response["two_step"] = two_step_state
        end
        super
      end

      # xxxx-xxxx-xxxx from an alphabet without look-alikes (60 bits).
      def new_recovery_code
        alphabet = "abcdefghjkmnpqrstuvwxyz23456789".chars
        Array.new(3) { Array.new(4) { alphabet[SecureRandom.random_number(alphabet.size)] }.join }.join("-")
      end

      def recovery_code_match?(code)
        normalized = code.to_s.downcase.gsub(/[^a-z0-9]/, "").scan(/.{1,4}/).join("-")
        super(normalized)
      end

      private

      def two_step_state
        if two_factor_partially_authenticated?
          "code"
        elsif two_step_setup_required?
          "setup"
        end
      end

      def two_step_setup_required?
        return false unless logged_in? && !two_factor_authenticated?
        return @two_step_setup_required if defined?(@two_step_setup_required)

        @two_step_setup_required = !uses_two_factor_authentication? && TwoStepPolicy.required?(session_value)
      end
    end
  end
end
