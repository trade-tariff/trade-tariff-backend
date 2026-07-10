module Api
  module V3
    class MeasureTypesController < BaseController
      def index
        measure_types = MeasureType.eager(:measure_type_description, :measure_type_series_description).actual.all
        render json: Api::V3::MeasureTypeSerializer.collection(measure_types)
      end

      def show
        measure_type = MeasureType.where(measure_type_id: params[:id]).take
        raise Sequel::RecordNotFound, "Measure type #{params[:id]} not found" if measure_type.nil?

        render json: Api::V3::MeasureTypeSerializer.new(measure_type).call
      end
    end
  end
end
