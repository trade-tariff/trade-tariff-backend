module Api
  module V2
    class CommoditiesController < ApiController
      before_action :find_commodity, only: %i[show changes]
      before_action :set_meursing_additional_code, only: :show

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

        raise Sequel::RecordNotFound if commodity_has_children?
        raise Sequel::RecordNotFound if @commodity.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
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

      def commodity_has_children?
        cache_key = "commodity-#{@commodity.goods_nomenclature_sid}-#{actual_date}-has-children?"

        Rails.cache.fetch(cache_key, expires_in: CachedCommodityService::TTL) do
          @commodity.children.any?
        end
      end

      def set_meursing_additional_code
        Thread.current[:meursing_additional_code_id] = filter_params[:meursing_additional_code_id]
      end
    end
  end
end
