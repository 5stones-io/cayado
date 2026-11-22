module Cayado
  module Api
    module V1
      # GET /api/v1/team: this church's staff, for the lead and editor
      # pickers. Sorted by name.
      class TeamController < BaseController
        include Cayado::PlanningJson

        def show
          team = Current.church.memberships.includes(:account).map { person_json(_1).merge(role: _1.role) }
          render json: { team: team.sort_by { [_1[:name].downcase, _1[:membership_id]] } }
        end
      end
    end
  end
end
