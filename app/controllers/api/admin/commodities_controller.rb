module Api
  module Admin
    class CommoditiesController < AdminController
      before_action :find_commodity, only: [:show]

      def show
        render json: Api::Admin::Commodities::CommoditySerializer.new(@commodity).serializable_hash
      end

      private

      def find_commodity
        @commodity = GoodsNomenclature
          .actual
          .with_leaf_column
          .by_code(commodity_code)
          .by_productline_suffix(productline_suffix)
          .take

        raise Sequel::RecordNotFound if @commodity.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def commodity_code
        params[:id].split('-', 2).first
      end

      def productline_suffix
        params[:id].split('-', 2)[1] || GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX
      end
    end
  end
end
