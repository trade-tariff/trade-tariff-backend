module Api
  module V2
    class CommoditiesController < ApiController
      before_action :find_commodity, only: %i[show changes]

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
                              .declarable
                              .by_code(params[:id])
                              .eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions, :footnotes)
                              .take

        raise Sequel::RecordNotFound if @commodity.children.any?
        raise Sequel::RecordNotFound if @commodity.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def cached_commodity
        CachedCommodityService.new(@commodity, actual_date, filter_params).call
      end

      def filter_params
        params.require(:filter).permit(:geographical_area_id, :meursing_additional_code_id) if params[:filter].present?
      end
    end
  end
end
