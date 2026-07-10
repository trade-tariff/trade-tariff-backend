module Api
  module V3
    class GeographicalAreasController < BaseController
      def index
        render json: CachedGeographicalAreaService.new(actual_date, exclude_none: false, countries: false).call
      end

      def show
        area = GeographicalArea.actual
          .by_id(params[:id])
          .eager(:geographical_area_descriptions)
          .take
        raise Sequel::RecordNotFound, "Geographical area #{params[:id]} not found" if area.nil?

        render json: Api::V3::GeographicalAreaSerializer.new(area).call
      end
    end
  end
end
