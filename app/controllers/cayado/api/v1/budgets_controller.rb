module Cayado
  module Api
    module V1
      # Admin: the year's monthly giving budget (/budgets/2026).
      class BudgetsController < BaseController
        include Cayado::HealthJson

        before_action :require_admin!

        def update
          budget = Current.church.budgets.find_or_initialize_by(year: params[:year].to_i)
          created = budget.new_record?
          return render_errors(budget) unless budget.update(monthly_cents: params[:monthly_cents])

          render json: budget_json(budget), status: created ? :created : :ok
        end

        def destroy
          Current.church.budgets.find_by!(year: params[:year].to_i).destroy!
          head :no_content
        end
      end
    end
  end
end
