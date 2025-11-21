module Api
  module User
    class GroupedMeasureCommodityChangesController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!

      def show
        render json: serialize(tariff_changes)
      end

      private

      def tariff_changes
        Api::User::GroupedMeasureCommodityChangesService.new(id, as_of).call
      end

      def serialize(tariff_changes)
        Api::User::GroupedMeasureCommodityChangeSerializer.new(tariff_changes, serializer_options).serializable_hash
      end

      def serializer_options
        {
          include: %w[
            commodity
            grouped_measure_change
            grouped_measure_change.geographical_area
            grouped_measure_change.excluded_countries
          ],
          params: { date: as_of },
        }
      end

      def as_of
        params[:as_of] || Time.zone.yesterday.to_date.to_s
      end

      def id
        params[:id]
      end
    end
  end
end
