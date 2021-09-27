module Api
  module V2
    class MeursingMeasuresController < ApiController
      DEFAULT_INCLUDES = %w[
        additional_code
        geographical_area
        measure_components
        measure_components.duty_expression
        measure_type
      ].freeze

      def index
        render json: serialized_meursing_measures
      end

      private

      def serialized_meursing_measures
        Api::V2::Measures::MeursingMeasureSerializer.new(presented_meursing_measures, serializer_options).serializable_hash
      end

      def serializer_options
        {
          include: DEFAULT_INCLUDES,
          meta: { duty_expression:  MeursingMeasureComponentFormatterService.new(root_measure, meursing_measures).call },
        }
      end

      def presented_meursing_measures
        meursing_measures.map { |measure| Api::V2::Measures::MeursingMeasurePresenter.new(measure) }
      end

      def meursing_measures
        @meursing_measures ||= root_measure
          .meursing_measures_for(additional_code_id)
          .actual
          .eager(
            :additional_code,
            :geographical_area,
            :measure_components,
            :measure_type,
            measure_components: [:duty_expression],
          )
          .all
          .select(&:current?)
      end

      def root_measure
        @root_measure ||= Measure
          .filter(measure_sid: measure_sid)
          .actual
          .take.tap do |measure|
            raise Sequel::RecordNotFound if measure.blank?
          end
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
