module Cayado
  module Api
    module V1
      # GET /api/v1/me: who's signed in and what they are at this church.
      class MeController < BaseController
        def show
          account = Current.account
          membership = Current.membership
          church = Current.church
          render json: {
            id: account.id,
            email: account.email,
            first_name: account.first_name,
            last_name: account.last_name,
            # nil until they've given one; show the email instead.
            name: account.name,
            role: membership.role,
            title: membership.title,
            admin: membership.admin_or_owner?,
            church: {
              name: church.brand_name,
              slug: church.slug,
              timezone: church.time_zone.tzinfo.name,
            },
          }
        end
      end
    end
  end
end
