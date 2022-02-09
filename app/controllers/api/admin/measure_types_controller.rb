module Api
  module Admin
    class MeasureTypesController < ApiController
      before_action :authenticate_user!

      def index
        @measure_types = MeasureType.eager(:measure_type_description).national.all

        render json: Api::Admin::MeasureTypeSerializer.new(@measure_types).serializable_hash
      end

      def show
        @measure_type = MeasureType.national.with_pk!(measure_type_pk)

        render json: Api::Admin::MeasureTypeSerializer.new(@measure_type, { is_collection: false }).serializable_hash
      end

      def update
        @measure_type = MeasureType.national.with_pk!(measure_type_pk)
        @measure_type.measure_type_description.tap do |measure_type_description|
          measure_type_description.set(measure_type_params[:attributes])
          measure_type_description.save
        end

        render json: Api::Admin::MeasureTypeSerializer.new(@measure_type, { is_collection: false }).serializable_hash
      end

      private

      def measure_type_params
        params.require(:data).permit(:type, attributes: [:description])
      end

      def measure_type_pk
        params.fetch(:id, '')
      end
    end
  end
end
