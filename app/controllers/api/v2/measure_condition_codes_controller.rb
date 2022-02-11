module Api
  module V2
    class MeasureConditionCodesController < ApiController
      def index
        render json: Api::V2::MeasureConditionCodeSerializer.new(measure_condition_codes).serializable_hash
      end

      private

      def measure_condition_codes
        MeasureConditionCode
          .actual
          .eager(:measure_condition_code_description)
          .all
      end
    end
  end
end
