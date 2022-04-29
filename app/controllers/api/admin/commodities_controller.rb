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
              Api::Admin::Commodities::CommodityCsvSerializer.new(all_commodities).serialized_csv,
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

      def all_commodities
        commodity_groups = []

        # Splitting the queries this way make the execution faster
        (0..9).each do |starting_digit|
          commodity_groups << Sequel::Model.db.fetch("select * from utils.goods_nomenclature_export_new(?, '2022-04-27') order by 2, 3", "#{starting_digit}%")
        end

        # Running the queries and merging ...'
        commodity_groups.map(&:to_a).flatten
      end
    end
  end
end
