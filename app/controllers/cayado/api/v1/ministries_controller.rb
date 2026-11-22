module Cayado
  module Api
    module V1
      # The ministries that plan against each sermon week (the alignment
      # slots). Everyone reads; admins add, rename, recolor, set leads and
      # remove. The key never changes: plan URLs and the apps use it.
      class MinistriesController < BaseController
        include Cayado::PlanningJson

        EDITABLE = %i[name color position lead_membership_id].freeze
        private_constant :EDITABLE

        before_action :require_admin!, except: [:index]

        def index
          render json: { ministries: ministries.map { ministry_json(_1) } }
        end

        def create
          ministry = Current.church.ministries.new(params.permit(:key, *EDITABLE))
          ministry.position = (Current.church.ministries.maximum(:position) || 0) + 1 unless params.key?(:position)
          return render_errors(ministry) unless ministry.save

          render json: ministry_json(ministry), status: :created
        end

        def update
          ministry = find_ministry
          return render_errors(ministry) unless ministry.update(params.permit(*EDITABLE))

          render json: ministry_json(ministry)
        end

        def destroy
          find_ministry.destroy!
          head :no_content
        end

        private

        def find_ministry
          Current.church.ministries.find_by!(key: params[:key])
        end
      end
    end
  end
end
