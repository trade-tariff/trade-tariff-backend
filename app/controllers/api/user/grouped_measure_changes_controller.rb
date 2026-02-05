module Api
  module User
    class GroupedMeasureChangesController < UserController
      include Pageable

      def index
        render json: serialize
      end

      def show
        render json: serialize
      end

      private

      def tariff_changes
        @tariff_changes ||= Api::User::GroupedMeasureChangesService.new(current_user, id, actual_date).call(page: current_page, per_page:)
      end

      def serialize
        Api::User::GroupedMeasureChangeSerializer.new(tariff_changes, serializer_options).serializable_hash
      end

      # Required for Pageable module
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

      def id
        params[:id]
      end
    end
  end
end
