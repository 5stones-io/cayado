# frozen_string_literal: true

require "rodauth"

# Set or reset a password with an emailed 6-digit code, in place of
# Rodauth's reset_password (which emails a link). A code works the same in
# the mobile app, where a link would open the browser instead, and on the
# web. It's also how an invited person sets their first password.
#
#   POST /auth/password-code-request  { email }
#     Emails a code. Always answers the same, whether or not the email has
#     an account; an unknown email gets an account created, since invites
#     rely on that and an account alone grants nothing without a Membership.
#
#   POST /auth/password-code-set  { email, code, password }
#     A wrong, expired or used code is a 401. A password the server won't
#     take is a 422 whose error says why. Otherwise the password is set, any
#     lockout is cleared, and the account is signed in, exactly like a
#     password login (so two-step sign-in may still follow).
#
# Required explicitly by CayadoRodauthMain, since Rodauth looks for
# features under rodauth/features/ on the load path and lib/ isn't on it.
module Rodauth
  Feature.define(:password_code, :PasswordCode) do
    depends :login, :login_password_requirements_base

    auth_value_method :password_code_param, "code"
    translatable_method :password_code_sent_message, "If that email can sign in, we sent it a code."
    translatable_method :invalid_password_code_message, "That code is wrong or has expired."

    auth_methods :password_code_link

    route(:password_code_request) do |r|
      r.post do
        login = param(login_param).to_s.strip.downcase

        catch_error do
          unless login_meets_requirements?(login)
            throw_error_reason(:login_not_valid_email, invalid_field_error_status, login_param, login_does_not_meet_requirements_message)
          end

          account = Account.find_or_create_by!(email: login)
          if account.status_id != 3 && (code = AccountPasswordCode.issue!(account))
            AuthEmail.password_code(email: login, code: code, link: password_code_link(login, code))
          end

          json_response[json_response_success_key] = password_code_sent_message
          return_json_response
        end

        set_error_flash login_does_not_meet_requirements_message
        return_json_response
      end
    end

    route(:password_code_set) do |r|
      r.post do
        login    = param(login_param).to_s.strip.downcase
        password = param(password_param).to_s

        message = invalid_password_code_message
        catch_error do
          unless account_from_login(login) && AccountPasswordCode.valid_for?(Account.find(account_id), param(password_code_param))
            throw_error_reason(:invalid_password_code, 401, password_code_param, message)
          end

          unless password_meets_requirements?(password)
            message = password_does_not_meet_requirements_message
            throw_error_reason(:password_does_not_meet_requirements, invalid_field_error_status, password_param, message)
          end

          transaction do
            set_password(password)
            AccountPasswordCode.consume!(Account.find(account_id))
            unlock_account if respond_to?(:unlock_account, true)
          end
          login("password")
        end

        set_error_flash message
        return_json_response
      end
    end

    private

    # The web screen that fills the code in (web sign-in). The app ignores it and
    # has the user type the code.
    def password_code_link(login, code)
      "#{scope.request.base_url}/set-password?#{URI.encode_www_form(email: login, code: code)}"
    end
  end
end
