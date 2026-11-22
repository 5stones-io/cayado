module Cayado
  module Api
    module V1
      # PUT/DELETE /api/v1/sermon_weeks/:sermon_week_id/plans/:ministry_key:
      # a ministry lead (or an admin) writes or clears their slot. Answers
      # with the slot either way.
      class AlignmentPlansController < BaseController
        include Cayado::PlanningJson

        before_action :set_week_and_ministry

        def update
          plan = @week.alignment_plans.find_or_initialize_by(ministry: @ministry)
          plan.assign_attributes(params.permit(:body, :memory_verse))
          plan.updated_by_membership = Current.membership
          return render_errors(plan) unless plan.save

          render json: slot_json(@ministry, plan)
        end

        def destroy
          @week.alignment_plans.where(ministry: @ministry).destroy_all
          render json: slot_json(@ministry, nil)
        end

        private

        def set_week_and_ministry
          @week = SermonWeek.for_church(Current.church).find(params[:sermon_week_id])
          @ministry = Current.church.ministries.find_by!(key: params[:ministry_key])
          return if @ministry.plannable_by?(Current.membership)

          render json: { error: "Only #{@ministry.name}'s lead or an admin can plan this", code: "forbidden" },
                 status: :forbidden
        end
      end
    end
  end
end
