module Api
  module V2
    class SubheadingsController < ApiController
      def show
        render json: cached_subheading
      end

      private

      def cached_subheading
        CachedSubheadingService.new(
          subheading,
          actual_date.iso8601,
          use_nested_set: TradeTariffBackend.nested_set_subheadings?,
        ).call
      end

      def subheading
        return ns_subheading if TradeTariffBackend.nested_set_subheadings?

        @subheading = Subheading.actual
                              .by_code(subheading_code)
                              .by_productline_suffix(productline_suffix)
                              .eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions, :footnotes)
                              .take

        raise Sequel::RecordNotFound unless subheading_has_children?
        raise Sequel::RecordNotFound if @subheading.goods_nomenclature_item_id.in?(HiddenGoodsNomenclature.codes)

        @subheading
      end

      def subheading_has_children?
        # Using the same cache key as commodity to reduce expensive operations
        cache_key = "commodity-#{@subheading.goods_nomenclature_sid}-#{actual_date}-has-children?"

        Rails.cache.fetch(cache_key, expires_in: CachedCommodityService::TTL) do
          @subheading.children.any?
        end
      end

      def subheading_code
        params[:id].split('-', 2).first
      end

      def productline_suffix
        params[:id].split('-', 2)[1] || '80'
      end

      def ns_subheading
        Subheading.actual
                  .non_hidden
                  .by_code(subheading_code)
                  .by_productline_suffix(productline_suffix)
                  .take
                  .tap { |sh| raise Sequel::RecordNotFound if sh.ns_leaf? }
      end
    end
  end
end
