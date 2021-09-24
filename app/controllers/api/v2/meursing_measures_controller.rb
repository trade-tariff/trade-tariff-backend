module Api
  module V2
    class MeursingMeasuresController < ApiController
      DEFAULT_INCLUDES = %w[
        measure_components
        measure_components.duty_expression
      ].freeze

      def index
        render json: serialized_meursing_measures
      end

      private

      def serialized_meursing_measures
        Api::V2::Measures::MeasureSerializer.new(
          meursing_measures, serializer_options
        ).serializable_hash
      end

      def serializer_options
        { include: DEFAULT_INCLUDES }
      end

      def meursing_measures
        measure.meursing_measures(additional_code_id)
      end

      def measure
        Measure.by_sid(measure_sid)
      end

      def measure_sid
        filter_params[:measure_sid]
      end

      def additional_code_id
        filter_params[:additional_code_id]
      end

      def filter_params
        params.require(:filter).permit(:measure_sid, :additional_code_id)
      end
    end
  end
end
