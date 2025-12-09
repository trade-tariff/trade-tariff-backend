module Api
  module User
    class GroupedMeasureChangesController < ApiController
      include PublicUserAuthenticatable
      include Pageable

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
        @tariff_changes ||= Api::User::GroupedMeasureChangesService.new(@current_user, id, as_of).call(page: current_page, per_page:)
      end

      def serialize(tariff_changes)
        Api::User::GroupedMeasureChangeSerializer.new(tariff_changes, serializer_options).serializable_hash
      end

      def record_count
        tariff_changes.count
      end

      def serializer_options
        pagination_meta.merge(
          include: %w[
            geographical_area
            excluded_countries
            grouped_measure_commodity_changes
            grouped_measure_commodity_changes.commodity
          ],
        )
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
