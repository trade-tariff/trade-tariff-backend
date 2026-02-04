module Api
  module User
    class GroupedMeasureCommodityChangesController < UserController
      def show
        render json: Api::User::GroupedMeasureCommodityChangeSerializer.new(tariff_changes, serializer_options).serializable_hash
      end

      private

      def tariff_changes
        TariffChanges::GroupedMeasureCommodityChange.from_id(id)
      end

      def serializer_options
        {
          include: %w[
            commodity
            grouped_measure_change
            grouped_measure_change.geographical_area
            grouped_measure_change.excluded_countries
          ],
          params: { date: actual_date.to_s },
        }
      end

      def id
        params[:id]
      end
    end
  end
end
