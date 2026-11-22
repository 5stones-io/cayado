module Cayado
  module Api
    module V1
      # Admins add and remove pillars and name their editors; a pillar's
      # editors change its words.
      class PillarsController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!, only: [:create, :destroy]

        def create
          vision = Vision.find_by!(church: Current.church)
          pillar = vision.pillars.new(pillar_params)
          pillar.position = (vision.pillars.maximum(:position) || 0) + 1 unless params.key?(:position)
          return render_errors(pillar) unless pillar.save

          render json: pillar_json(pillar), status: :created
        end

        def update
          pillar = find_pillar
          return forbidden unless pillar.editable_by?(Current.membership)
          return forbidden if params.key?(:editor_membership_ids) && !admin?

          saved = Pillar.transaction do
            replace_editors(pillar) if params.key?(:editor_membership_ids)
            pillar.update(pillar_params) || raise(ActiveRecord::Rollback)
          end
          return render_errors(pillar) unless saved

          render json: pillar_json(pillar.reload)
        rescue ActiveRecord::RecordInvalid => e
          render_errors(e.record)
        end

        def destroy
          find_pillar.destroy!
          head :no_content
        end

        private

        def find_pillar
          Pillar.for_church(Current.church).find(params[:id])
        end

        def pillar_params
          params.permit(:title, :blurb, :tone, :position)
        end

        # An empty list ([""] over a form post) clears the editors.
        def replace_editors(pillar)
          ids = Array(params[:editor_membership_ids]).compact_blank.map(&:to_i)
          pillar.pillar_editors.where.not(membership_id: ids).destroy_all
          (ids - pillar.pillar_editors.pluck(:membership_id)).each do |id|
            pillar.pillar_editors.create!(membership: Membership.find_by(id: id))
          end
        end

        def forbidden
          render json: { error: "Only an admin or this pillar's editors can do that", code: "forbidden" }, status: :forbidden
        end
      end
    end
  end
end
