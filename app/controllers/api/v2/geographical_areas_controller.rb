module Api
  module V2
    class GeographicalAreasController < ApiController
      def index
        @geographical_areas = GeographicalArea.eager(:geographical_area_descriptions).actual.areas.all

        render json: Api::V2::GeographicalAreaTreeSerializer.new(@geographical_areas, options).serializable_hash
      end

      def countries
        @geographical_areas = GeographicalArea.eager(:geographical_area_descriptions).actual.countries.all

        render json: Api::V2::GeographicalAreaTreeSerializer.new(@geographical_areas, options).serializable_hash
      end

      def options
        { include: [:contained_geographical_areas] }
      end
    end
  end
end
