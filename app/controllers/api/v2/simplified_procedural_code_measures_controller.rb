module Api
  module V2
    class SimplifiedProceduralCodeMeasuresController < ApiController
      def index
        render json: serialized_simplified_procedural_code_measures
      end

      private

      def serialized_simplified_procedural_code_measures
        Api::V2::SimplifiedProceduralCodeMeasureSerializer.new(all_simplified_procedural_code_measures)
      end

      def all_simplified_procedural_code_measures
        return simplified_procedural_code_measures.values.flatten if filtering_by_code?

        SimplifiedProceduralCode.all_null_measures.each_with_object([]) do |null_measure, acc|
          measures = simplified_procedural_code_measures[null_measure.simplified_procedural_code].presence || null_measure

          acc.concat(Array.wrap(measures))
        end
      end

      def simplified_procedural_code_measures
        @simplified_procedural_code_measures ||= SimplifiedProceduralCodeMeasure
          .with_filter(simplified_procedural_code_params)
          .each_with_object({}) do |measure, acc|
            acc[measure.simplified_procedural_code] ||= []
            acc[measure.simplified_procedural_code] << measure
          end
      end

      def simplified_procedural_code_params
        params.fetch(:filter, {}).permit(
          :simplified_procedural_code,
          :from_date,
          :to_date,
        )
      end

      def filtering_by_code?
        simplified_procedural_code_params[:simplified_procedural_code].present?
      end
    end
  end
end
