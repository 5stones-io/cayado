module Cayado
  module Api
    module V1
      # GET /api/v1/two_step: the signed-in account's two-step sign-in, for
      # Profile: whether it's on, whether it's required, and how many
      # recovery codes are left. Setting it up and new codes go through
      # Rodauth's own /auth routes (CayadoRodauthMain).
      class TwoStepController < BaseController
        def show
          id = Integer(Current.account.id)
          connection = ActiveRecord::Base.connection
          render json: {
            enabled: connection.select_value("SELECT 1 FROM account_otp_keys WHERE id = #{id}").present?,
            required: TwoStepPolicy.required?(id),
            recovery_codes_left: connection.select_value("SELECT COUNT(*) FROM account_recovery_codes WHERE id = #{id}").to_i,
          }
        end
      end
    end
  end
end
