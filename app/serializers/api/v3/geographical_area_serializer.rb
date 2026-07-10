module Api
  module V3
    class GeographicalAreaSerializer
      def initialize(area)
        @area = area
      end

      def call
        {
          geographical_area_sid: @area.geographical_area_sid,
          geographical_area_id: @area.geographical_area_id,
          description: @area.description,
          geographical_code: @area.geographical_code,
          validity_start_date: @area.validity_start_date,
          validity_end_date: @area.validity_end_date,
        }
      end
    end
  end
end
