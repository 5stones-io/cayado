module Cayado
  module Api
    module V1
      # Docs on a roadmap item or a sermon series. Anyone on staff attaches;
      # whoever attached it (or an admin) edits or removes it.
      class AttachmentsController < BaseController
        include Cayado::PlanningJson

        def index
          render json: { attachments: attachable.attachments.order(updated_at: :desc, id: :desc).map { attachment_json(_1) } }
        end

        def create
          attachment = attachable.attachments.new(attachment_params.merge(church: Current.church, owner_membership: Current.membership))
          return render_errors(attachment) unless attachment.save

          render json: attachment_json(attachment), status: :created
        end

        def update
          attachment = find_attachment
          return forbidden unless attachment.editable_by?(Current.membership)
          return render_errors(attachment) unless attachment.update(attachment_params)

          render json: attachment_json(attachment)
        end

        def destroy
          attachment = find_attachment
          return forbidden unless attachment.editable_by?(Current.membership)

          attachment.destroy!
          head :no_content
        end

        private

        def attachable
          @attachable ||= if params[:roadmap_item_id]
                            Current.church.roadmap_items.find(params[:roadmap_item_id])
                          else
                            Current.church.sermon_series.find(params[:sermon_series_id])
                          end
        end

        def find_attachment
          Attachment.where(church: Current.church).find(params[:id])
        end

        def attachment_params
          params.permit(:title, :url, :kind, tags: [])
        end

        def forbidden
          render json: { error: "Only whoever attached it or an admin can do that", code: "forbidden" }, status: :forbidden
        end
      end
    end
  end
end
