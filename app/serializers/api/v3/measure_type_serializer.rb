module Api
  module V3
    class MeasureTypeSerializer
      def initialize(measure_type)
        @measure_type = measure_type
      end

      def call
        {
          id: @measure_type.measure_type_id,
          description: @measure_type.description,
          measure_type_series_id: @measure_type.measure_type_series_id,
          measure_type_series_description: @measure_type.measure_type_series_description&.description,
          measure_component_applicable_code: @measure_type.measure_component_applicable_code,
          order_number_capture_code: @measure_type.order_number_capture_code,
          trade_movement_code: @measure_type.trade_movement_code,
          validity_start_date: @measure_type.validity_start_date,
          validity_end_date: @measure_type.validity_end_date,
        }
      end

      def self.collection(measure_types)
        list = measure_types.map { |mt| new(mt).call }
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
