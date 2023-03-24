module Api
  module V2
    class SubheadingsController < ApiController
      def show
        render json: cached_subheading
      end

      private

      def cached_subheading
        CachedSubheadingService.new(subheading, actual_date.iso8601).call
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

      def ns_measures_eager_load
        {
          ns_overview_measures: [
            {
              measure_components: {
                duty_expression: :duty_expression_description,
                measurement_unit: %i[measurement_unit_description
                                     measurement_unit_abbreviations],
                monetary_unit: :monetary_unit_description,
                measurement_unit_qualifier: [],
              },
              measure_type: %i[measure_type_description
                               measure_type_series
                               measure_type_series_description],
            },
            :additional_code,
          ],
        }
      end

      def ns_eager_load
        [
          :goods_nomenclature_descriptions,
          :footnotes,
          ns_measures_eager_load,
          {
            ns_ancestors: [
              :goods_nomenclature_descriptions,
              ns_measures_eager_load,
            ],
            ns_descendants: [
              :goods_nomenclature_descriptions,
              ns_measures_eager_load,
            ],
          },
        ]
      end

      def ns_subheading
        @subheading = Subheading.actual
                                .non_hidden
                                .by_code(subheading_code)
                                .by_productline_suffix(productline_suffix)
                                .eager(*ns_eager_load)
                                .limit(1)
                                .all
                                .first

        raise Sequel::RecordNotFound if !@subheading || @subheading.ns_leaf?

        @subheading
      end
    end
  end
end
