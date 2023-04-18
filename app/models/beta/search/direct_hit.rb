module Beta
  module Search
    class DirectHit
      attr_accessor :goods_nomenclature_class,
                    :goods_nomenclature_item_id,
                    :producline_suffix

      def id
        "#{goods_nomenclature_item_id}-#{producline_suffix}"
      end

      def method_missing(method_name, *_arguments)
        if method_name.to_s.start_with?('search_references')
          []
        elsif method_name.to_s.start_with?('guide')
          []
        elsif method_name.to_s.start_with?('ancestors')
          []
        end
      end

      def respond_to_missing?(method_name, _include_private = false)
        method_name.to_s.start_with?('search_references') ||
          method_name.to_s.start_with?('guide') ||
          method_name.to_s.start_with?('ancestors')
      end

      def self.build(search_result)
        direct_hit = new

        if search_result.hits.one?
          direct_hit.goods_nomenclature_class = search_result.hits.first.goods_nomenclature_class
          direct_hit.goods_nomenclature_item_id = search_result.hits.first.goods_nomenclature_item_id
          direct_hit.producline_suffix = search_result.hits.first.producline_suffix
          direct_hit
        elsif search_result.goods_nomenclature.present?
          direct_hit.goods_nomenclature_class = search_result.goods_nomenclature.class.name
          direct_hit.goods_nomenclature_item_id = search_result.goods_nomenclature.goods_nomenclature_item_id
          direct_hit.producline_suffix = search_result.goods_nomenclature.producline_suffix
          direct_hit
        elsif search_result.numeric?
          short_code = search_result.short_code
          goods_nomenclature_class, goods_nomenclature_item_id, productline_suffix = ShortCodeClassificationService.new(short_code).call

          direct_hit.goods_nomenclature_class = goods_nomenclature_class
          direct_hit.goods_nomenclature_item_id = goods_nomenclature_item_id
          direct_hit.producline_suffix = productline_suffix
          direct_hit
        end
      end
    end
  end
end
