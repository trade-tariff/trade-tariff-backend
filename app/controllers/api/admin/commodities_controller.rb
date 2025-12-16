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
          .where(
            goods_nomenclatures__goods_nomenclature_item_id: commodity_code,
            goods_nomenclatures__producline_suffix: productline_suffix,
          )
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
