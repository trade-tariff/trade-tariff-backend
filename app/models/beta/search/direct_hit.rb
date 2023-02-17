module Beta
  module Search
    class DirectHit
      attr_accessor :goods_nomenclature_class,
                    :goods_nomenclature_item_id,
                    :producline_suffix

      attr_reader :description,
                  :formatted_description,
                  :validity_start_date,
                  :validity_end_date

      def id
        "#{goods_nomenclature_item_id}-#{producline_suffix}"
      end

      def self.build(search_result)
        direct_hit = new

        if search_result.hits.one?
          direct_hit.goods_nomenclature_class = search_result.hits.first.goods_nomenclature_class
          direct_hit.goods_nomenclature_item_id = search_result.hits.first.goods_nomenclature_item_id
          direct_hit.producline_suffix = search_result.hits.first.producline_suffix

          direct_hit
        elsif search_result.search_reference.present?
          direct_hit.goods_nomenclature_class = search_result.search_reference.referenced_class
          direct_hit.goods_nomenclature_item_id = search_result.search_reference.goods_nomenclature_item_id
          direct_hit.producline_suffix = search_result.search_reference.productline_suffix

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
