module Api
  module V2
    class HeadingsController < ApiController
      include SearchResultTracking

      before_action :track_result_selected, only: :show

      def show
        service = ::HeadingService::HeadingSerializationService.new(heading, actual_date, filter_params)
        render json: service.serializable_hash
      end

      def commodities
        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::CommoditySerializer.new(heading_commodities).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{TradeTariffBackend.service}-headings-#{params[:id]}-commodities-#{actual_date.iso8601}.csv",
            )
          end

          format.all do
            service = ::HeadingService::HeadingSerializationService.new(heading, actual_date)
            render json: service.serializable_hash
          end
        end
      end

      def changes
        key = "heading-#{heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(heading.changes.where do |o|
            o.operation_date <= actual_date
          end)
        end

        options = {}
        options[:include] = [:record, 'record.geographical_area', 'record.measure_type']
        render json: Api::V2::Changes::ChangeSerializer.new(@changes.changes, options).serializable_hash
      end

    private

      def heading_scope
        Heading.actual.non_grouping.non_hidden.by_code(params[:id])
      end

      def heading
        @heading ||= heading_scope.take
      end

      def heading_commodities
        heading_scope
          .eager(descendants: :goods_nomenclature_descriptions)
          .all
          .first
          .tap { |heading| heading || (raise Sequel::RecordNotFound) }
          .descendants
      end

      def filter_params
        params.fetch(:filter, {}).permit(:geographical_area_id)
      end
    end
  end
end
