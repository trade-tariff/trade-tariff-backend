module Api
  module V2
    class MeasureTypesController < ApiController
      def index
        @measure_types = MeasureType.eager(:measure_type_description).all

        render json:  Api::V2::Measures::MeasureTypeSerializer.new(@measure_types).serializable_hash
      end
    end
  end
end
