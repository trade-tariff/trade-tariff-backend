module Api
  module V2
    class GeographicalAreasController < ApiController
      def index
        render json: CachedGeographicalAreaService.new(actual_date, exclude_none:, countries: false).call
      end

      def show
        render json: serialized_geographical_area
      end

      def countries
        render json: CachedGeographicalAreaService.new(actual_date, exclude_none:, countries: true).call
      end

      private

      def serialized_geographical_area
        Api::V2::GeographicalAreaTreeSerializer.new(
          geographical_area,
          include: [:contained_geographical_areas],
        ).serializable_hash
      end

      def geographical_area
        GeographicalArea.actual.by_id(params[:id]).eager(:geographical_area_descriptions, :contained_geographical_areas).take
      end

      def exclude_none
        params.fetch(:filter, {}).permit(:exclude_none).fetch(:exclude_none, false) == 'true'
      end
    end
  end
end
