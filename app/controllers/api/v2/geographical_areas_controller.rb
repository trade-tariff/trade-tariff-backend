module Api
  module V2
    class GeographicalAreasController < ApiController
      def index
        render json: CachedGeographicalAreaService.new(actual_date).call
      end

      def countries
        render json: CachedGeographicalAreaService.new(actual_date, true).call
      end
    end
  end
end
