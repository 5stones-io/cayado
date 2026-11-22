module Cayado
  module Api
    module V1
      # A pillar's moves are written by whoever may edit the pillar.
      class MovesController < BaseController
        include Cayado::PlanningJson

        def create
          pillar = Pillar.for_church(Current.church).find(params[:pillar_id])
          return forbidden unless pillar.editable_by?(Current.membership)

          move = pillar.moves.new(move_params)
          move.position = (pillar.moves.maximum(:position) || 0) + 1 unless params.key?(:position)
          return render_errors(move) unless move.save

          render json: move_json(move), status: :created
        end

        def update
          move = find_move
          return forbidden unless move.pillar.editable_by?(Current.membership)
          return render_errors(move) unless move.update(move_params)

          render json: move_json(move)
        end

        def destroy
          move = find_move
          return forbidden unless move.pillar.editable_by?(Current.membership)

          move.destroy!
          head :no_content
        end

        private

        def find_move
          Move.for_church(Current.church).find(params[:id])
        end

        def move_params
          params.permit(:text, :position)
        end

        def forbidden
          render json: { error: "Only an admin or this pillar's editors can do that", code: "forbidden" }, status: :forbidden
        end
      end
    end
  end
end
