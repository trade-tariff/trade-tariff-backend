module Api
  module V2
    class GeographicalAreasController < ApiController
      TTL = 24.hours

      def index
        render json: cached_serialized_geographical_areas
      end

      def countries
        render json: cached_serialized_geographical_areas
      end

      private

      def cached_serialized_geographical_areas(countries: false)
        @serialized = Rails.cache.fetch(cache_key, expires_in: TTL) do
          geographical_areas = if countries
                                 GeographicalArea.eager(:geographical_area_descriptions).actual.countries.all
                               else
                                 GeographicalArea.eager(:geographical_area_descriptions).actual.areas.all
                               end

          Api::V2::GeographicalAreaTreeSerializer.new(
            geographical_areas,
            include: [:contained_geographical_areas],
          ).serializable_hash
        end
      end

      def cache_key
        "_geographical-areas-#{action_name}-#{actual_date}"
      end
    end
  end
end
