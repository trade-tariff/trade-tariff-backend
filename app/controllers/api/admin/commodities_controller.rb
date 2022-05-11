module Api
  module Admin
    class CommoditiesController < ApiController
      before_action :find_commodity, only: [:show]

      def show
        render json: Api::Admin::Commodities::CommoditySerializer.new(@commodity, { is_collection: false }).serializable_hash
      end

      def index
        respond_to do |format|
          format.csv do
            send_data(
              Api::Admin::Commodities::CommodityCsvSerializer.new(
                ::Admin::QueryAllCommodities.call(actual_date),
              ).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{TradeTariffBackend.service}-commodities-#{actual_date.iso8601}.csv",
            )
          end
        end
      end

      private

      def find_commodity
        @commodity = Commodity.actual
                              .by_productline_suffix(productline_suffix)
                              .by_code(commodity_code)
                              .take

        raise Sequel::RecordNotFound if @commodity.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def commodity_code
        params[:id].split('-', 2).first
      end

      def productline_suffix
        params[:id].split('-', 2)[1] || '80'
      end
    end
  end
end
