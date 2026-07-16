module Api
  module V3
    class GeographicalAreasController < BaseController
      def index
        areas = GeographicalArea.actual
          .eager(:geographical_area_descriptions)
          .all
        render json: Api::V3::GeographicalAreaSerializer.collection(areas)
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
