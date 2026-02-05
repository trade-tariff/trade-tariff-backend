module Api
  module V2
    class CommoditiesController < ApiController
      include SearchResultTracking

      before_action :track_result_selected, only: :show
      before_action :find_commodity, only: %i[show changes]
      around_action :configure_meursing_additional_code, only: :show

      def show
        render json: cached_commodity
      end

      def changes
        @changes = ChangeLog.new(@commodity.changes.where do |o|
                                   o.operation_date <= actual_date
                                 end)

        options = {}
        options[:include] = [:record, 'record.geographical_area', 'record.measure_type']
        render json: Api::V2::Changes::ChangeSerializer.new(@changes.changes, options).serializable_hash
      end

      private

      def find_commodity
        @commodity = Commodity.actual
                              .non_hidden
                              .declarable
                              .by_code(params[:id])
                              .take
      end

      def cached_commodity
        CachedCommodityService.new(@commodity, actual_date, filter_params).call
      end

      def filter_params
        params.fetch(:filter, {}).permit(
          :geographical_area_id,
          :meursing_additional_code_id,
        )
      end

      def configure_meursing_additional_code
        TradeTariffRequest.meursing_additional_code_id = filter_params[:meursing_additional_code_id]

        yield
      ensure
        TradeTariffRequest.meursing_additional_code_id = nil
      end
    end
  end
end
