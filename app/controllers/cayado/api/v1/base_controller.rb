module Cayado
  module Api
    module V1
      # Every API call needs a church (from the Host header) and a fully
      # signed-in account (password and authenticator) that's on that
      # church's staff.
      class BaseController < ActionController::API
        include TenantResolution

        before_action :require_tenant!
        before_action :authenticate!
        before_action :require_membership!

        private

        def authenticate!
          unless rodauth.authenticated?
            render json: { error: "Unauthorized", code: "unauthorized" }, status: :unauthorized
            return
          end
          account_id = rodauth.session[rodauth.session_key]
          Current.account = Account.find_by(id: account_id)
          Current.membership = Current.account && Membership.find_by(account_id: account_id, church_id: Current.church.id)
        end

        # Signed in, but not on this church's staff.
        def require_membership!
          return if Current.membership

          render json: { error: "You're not on this church's team", code: "not_a_member" }, status: :forbidden
        end

        # Role is per church (Membership#role), resolved every request, not a
        # JWT claim.
        def admin? = Current.membership&.admin_or_owner? == true

        def require_admin!
          return if admin?

          render json: { error: "Forbidden", code: "forbidden" }, status: :forbidden
        end

        def render_errors(record)
          render json: { error: record.errors.full_messages.to_sentence, code: "invalid", errors: record.errors.to_hash },
                 status: :unprocessable_content
        end
      end
    end
  end
end
