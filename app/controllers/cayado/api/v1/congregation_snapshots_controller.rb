module Cayado
  module Api
    module V1
      # Admin: take, correct and remove congregation snapshots (manual until
      # Planning Center provides them).
      class CongregationSnapshotsController < BaseController
        include Cayado::HealthJson

        before_action :require_admin!

        def create
          snapshot = Current.church.congregation_snapshots.new(taken_on: Current.church.today)
          snapshot.assign_attributes(snapshot_params)
          return render_errors(snapshot) unless snapshot.save

          render json: snapshot_json(snapshot), status: :created
        end

        def update
          snapshot = Current.church.congregation_snapshots.find(params[:id])
          return render_errors(snapshot) unless snapshot.update(snapshot_params)

          render json: snapshot_json(snapshot)
        end

        def destroy
          Current.church.congregation_snapshots.find(params[:id]).destroy!
          head :no_content
        end

        private

        def snapshot_params
          permitted = params.permit(:taken_on, :households, :note,
                                    life_stages: [:label, :pct], season_markers: [:label, :count])
          %i[life_stages season_markers].each do |key|
            permitted[key] = permitted[key].map(&:to_h) if permitted.key?(key)
          end
          permitted.to_h
        end
      end
    end
  end
end
