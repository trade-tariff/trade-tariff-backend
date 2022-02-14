module Api
  module V2
    class MeasureActionsController < ApiController
      def index
        render json: Api::V2::MeasureActionSerializer.new(measure_actions).serializable_hash
      end

      private

      def measure_actions
        MeasureAction
          .actual
          .eager(:measure_action_description)
          .all
      end
    end
  end
end
