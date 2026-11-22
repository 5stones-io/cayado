module Cayado
  module Api
    module V1
      # GET /api/v1/tenant: which church this address is, for the sign-in
      # screen. No sign-in needed.
      class TenantController < ActionController::API
        include TenantResolution

        before_action :require_tenant!

        def show
          church = Current.church
          render json: {
            name: church.brand_name,
            hostname: church.primary_hostname,
          }
        end
      end
    end
  end
end
