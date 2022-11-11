module Api
  module V2
    class MeasuresController < ApiController
      def show
        render json: Api::V2::MeasureSerializer.new(presented_measure, serializer_options)
      end

      private

      def presented_measure
        measure = Measure
          .where(measure_sid: params[:id])
          .take

        @presented_measure = Api::V2::Measures::MeasurePresenter.new(measure, measure.goods_nomenclature)
      end

      def serializer_options
        {
          include: %w[
            goods_nomenclature
            duty_expression
            measure_type
            legal_acts
            measure_generating_legal_act
            justification_legal_act
            measure_conditions
            measure_conditions.measure_condition_components
            measure_components
            geographical_area
            geographical_area.contained_geographical_areas
            excluded_geographical_areas
            footnotes
            additional_code
            order_number
            order_number.definition
          ],
        }
      end
    end
  end
end
