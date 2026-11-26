module Cayado
  module Api
    module V1
      # Admin: pin a congregation snapshot to a sermon week (the latest one
      # unless congregation_snapshot_id says otherwise), or unpin it.
      class SermonWeekSnapshotsController < BaseController
        before_action :require_admin!
        before_action :find_week

        def update
          snapshot = if params[:congregation_snapshot_id].present?
                       Current.church.congregation_snapshots.find(params[:congregation_snapshot_id])
                     else
                       Current.church.congregation_snapshots.latest_first.first
                     end
          unless snapshot
            return render json: { error: "Take a congregation snapshot first", code: "no_snapshot" },
                          status: :unprocessable_content
          end

          @week.update!(congregation_snapshot: snapshot)
          render json: { sermon_week_id: @week.id, congregation_snapshot_id: snapshot.id }
        end

        def destroy
          @week.update!(congregation_snapshot: nil)
          head :no_content
        end

        private

        def find_week
          @week = SermonWeek.for_church(Current.church).find(params[:sermon_week_id])
        end
      end
    end
  end
end
