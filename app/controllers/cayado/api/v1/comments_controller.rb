module Cayado
  module Api
    module V1
      # The conversation on a sermon week. Anyone on staff posts; the author
      # or an admin deletes.
      class CommentsController < BaseController
        include Cayado::PlanningJson

        def create
          week = SermonWeek.for_church(Current.church).find(params[:sermon_week_id])
          comment = week.comments.new(body: params[:body], membership: Current.membership)
          return render_errors(comment) unless comment.save

          ActivityEvent.comment_added!(comment)

          render json: comment_json(comment), status: :created
        end

        def destroy
          comment = Comment.joins(sermon_week: :sermon_series)
                           .where(cayado_sermon_series: { church_id: Current.church.id })
                           .find(params[:id])
          unless comment.deletable_by?(Current.membership)
            return render json: { error: "Only its author or an admin can delete this", code: "forbidden" },
                          status: :forbidden
          end

          comment.destroy!
          head :no_content
        end
      end
    end
  end
end
