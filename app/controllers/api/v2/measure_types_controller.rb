module Api
  module V2
    class MeasureTypesController < ApiController
      def index
        @measure_types = MeasureType.eager(:measure_type_description, :measure_type_series_description).actual.all

        render json: Api::V2::Measures::MeasureTypeSerializer.new(@measure_types).serializable_hash
      end

      def show
        measure_type = MeasureType.where(measure_type_id: params[:id]).take

        serializer = Api::V2::Measures::MeasureTypeSerializer.new(measure_type)

        render json: serializer.serializable_hash
      end
    end
  end
end
