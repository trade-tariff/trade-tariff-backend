module GoodsNomenclatures
  module NestedSet
    module Populators
      def recursive_ancestor_populator(ancestors)
        @associations ||= {}
        @associations[:ancestors] ||= ancestors

        parents_ancestors = ancestors.dup
        parent = parents_ancestors.pop
        @associations[:parent] ||= parent
        return if ancestors.empty?

        parent.recursive_ancestor_populator(parents_ancestors)
      end

      def recursive_descendant_populator(descendants, parent = nil)
        @associations ||= {}
        @associations[:descendants] ||= descendants

        if parent
          @associations[:parent] ||= parent

          if parent.associations[:ancestors]
            @associations[:ancestors] ||= (parent.associations[:ancestors] + [parent])
          end
        end

        if descendants.empty?
          @associations[:children] ||= []
          return
        end

        grouped_by_child = descendants.each.with_object({}) do |descendant, all_children|
          if descendant.depth == (depth + 1)
            all_children[descendant] = []
          elsif (last_child = all_children.keys.last)
            all_children[last_child] << descendant
          end
        end

        @associations[:children] ||= grouped_by_child.map do |child, childs_descendants|
          child.recursive_descendant_populator(childs_descendants, self)

          child
        end
      end
    end
  end
end
