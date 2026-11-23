module Cayado
  module Api
    module V1
      # Major events, outreach and ministry initiatives. Everyone on staff
      # reads; admins write (as with series).
      class RoadmapItemsController < BaseController
        include Cayado::PlanningJson

        before_action :require_admin!, only: [:create, :update, :destroy]
        before_action :set_item, only: [:show, :update, :destroy]

        def show
          render json: roadmap_item_json(@item).merge(attachments: @item.attachments.order(updated_at: :desc, id: :desc).map { attachment_json(_1) })
        end

        def create
          item = Current.church.roadmap_items.new(item_params)
          return render_errors(item) unless item.save

          render json: roadmap_item_json(item), status: :created
        end

        def update
          return render_errors(@item) unless @item.update(item_params)

          render json: roadmap_item_json(@item)
        end

        def destroy
          @item.destroy!
          head :no_content
        end

        private

        def set_item
          @item = Current.church.roadmap_items.find(params[:id])
        end

        def item_params
          params.permit(:lane, :title, :starts_on, :ends_on, :color, :owner_membership_id, :notes, :pillar_id, :move_id)
        end
      end
    end
  end
end
