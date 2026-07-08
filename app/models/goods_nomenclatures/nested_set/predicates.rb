module GoodsNomenclatures
  module NestedSet
    module Predicates
      def depth
        values.key?(:depth) ? values[:depth] : tree_node.depth
      end

      def declarable?
        producline_suffix == GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX && leaf?
      end

      def leaf?
        values.key?(:leaf) ? values[:leaf] : children.empty?
      end

      def applicable_measures
        (ancestors.flat_map(&:measures) + measures).sort
      end

      def applicable_overview_measures
        (ancestors.flat_map(&:overview_measures) + overview_measures).sort
      end
    end
  end
end
