module GoodsNomenclatures
  module Overrides
    module Chapter
      # No op
    end

    module Heading
      def commodities
        @commodities ||= \
          ns_descendants_dataset.exclude(
            goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes,
          ).all
      end

      def declarable?
        ns_declarable?
      end

      def declarable
        ns_declarable?
      end
    end

    module Subheading
      def commodities
        @commodities ||= ancestors + [self] + ns_descendants_without_hidden
      end

    private

      def ns_descendants_without_hidden
        ns_descendants_dataset
          .exclude(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes)
          .eager(:goods_nomenclature_indents)
          .all
      end
    end

    module Commodity
      def ancestors
        @ancestors ||= ns_ancestors.select { |ancestor| ancestor.depth > 2 }
      end

      def uptree
        ns_ancestors + [self]
      end

      def children
        @children ||= begin
          ns_descendants # trigger loading of entire subtree

          hidden_codes = HiddenGoodsNomenclature.codes

          ns_children.reject do |child|
            child.goods_nomenclature_item_id.in?(hidden_codes)
          end
        end
      end

      def declarable?
        Rails.cache.fetch(declarable_cache_key) do
          ns_declarable?
        end
      end

      def number_indents
        if !values.key?(:depth)
          super
        elsif values[:depth] > 1
          values[:depth] - 2
        else
          0
        end
      end
    end
  end
end
