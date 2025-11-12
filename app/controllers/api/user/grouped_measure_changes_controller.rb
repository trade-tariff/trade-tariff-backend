module Api
  module User
    class GroupedMeasureChangesController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!

      def index
        render json: serialize(tariff_changes)
      end

      def show
        render json: serialize(tariff_changes)
      end

      private

      def tariff_changes
        Api::User::GroupedMeasureChangesService.new(@current_user, id, as_of).call
      end

      def serialize(tariff_changes)
        Api::User::GroupedMeasureChangeSerializer.new(tariff_changes, serializer_options).serializable_hash
      end

      def serializer_options
        {
          include: %w[
            geographical_area
            excluded_countries
            grouped_measure_commodity_changes
            grouped_measure_commodity_changes.commodity
          ],
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
