module Api
  module User
    class GroupedMeasureCommodityChangesController < UserController
      def show
        if grouped_measure_commodity_change.nil?
          render json: { error: 'No changes found' }, status: :not_found and return
        end

        render json: Api::User::GroupedMeasureCommodityChangeSerializer.new(grouped_measure_commodity_change, serializer_options).serializable_hash
      end

      private

      def grouped_measure_commodity_change
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
