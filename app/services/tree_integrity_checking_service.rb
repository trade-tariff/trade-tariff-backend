class TreeIntegrityCheckingService
  attr_reader :failures

  def initialize
    @failures = Set.new
  end

  def check!
    Chapter.actual.all.each do |chapter|
      check_for_tree_break!(chapter)
    end

    check_for_missing_indent!

    @failures.empty?
  end

  private

  def check_for_tree_break!(chapter)
    chapter.ns_descendants.each do |descendant|
      if (descendant.ns_children.empty? && descendant.ns_descendants.any?) ||
          descendant.ns_parent.nil?
        @failures << descendant.goods_nomenclature_sid
      end
    end
  end

  def check_for_missing_indent!
    @failures += GoodsNomenclature
      .actual
      .select(:goods_nomenclatures__goods_nomenclature_sid)
      .association_left_join(:tree_node)
      .where(tree_node__goods_nomenclature_sid: nil)
      .all
      .map(&:goods_nomenclature_sid)
  end
end
