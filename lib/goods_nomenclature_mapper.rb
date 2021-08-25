class GoodsNomenclatureMapper
  module MappedGoodsNomenclature
    attr_writer :ancestors
    attr_accessor :parent

    def children
      @children ||= []
    end

    def child_ids
      children.map(&:goods_nomenclature_sid)
    end

    def leaf?
      children.empty?
    end
    alias :leaf :leaf?

    def ancestors
      @ancestors ||= []
    end
  end

  # speed up the lookup without doing mongo queries
  attr_reader :parent_map

  def initialize(goods_nomenclatures)
    @goods_nomenclatures = goods_nomenclatures.map { |goods_nomenclature| goods_nomenclature.extend(MappedGoodsNomenclature) }
    @parent_map = {}

    process
  end

  def goods_nomenclatures
    @goods_nomenclatures.reject { |goods_nomenclature| goods_nomenclature.parent.present? }
  end
  alias :root_entries :goods_nomenclatures

  def all
    @goods_nomenclatures
  end

  def find
    @goods_nomenclatures.detect { |c| yield(c) } if block_given?
  end
  alias :detect :find

  def for_goods_nomenclature(ref_goods_nomenclature)
    detect { |goods_nomenclature| goods_nomenclature.goods_nomenclature_sid == ref_goods_nomenclature.goods_nomenclature_sid }
  end

  private

  def process
    # first pair
    traverse(goods_nomenclatures, nil, goods_nomenclatures.first)
    # all other pairs
    traverse(goods_nomenclatures, goods_nomenclatures.first, goods_nomenclatures.second)
  end

  def traverse(goods_nomenclatures, primary, secondary)
    # ignore case when first goods_nomenclature is blank it's a direct child of the heading
    unless goods_nomenclatures.index(secondary).blank?
      next_goods_nomenclature = goods_nomenclatures[goods_nomenclatures.index(secondary) + 1]
      if next_goods_nomenclature.present? # we are not at the end of the goods_nomenclature array
        map_goods_nomenclatures(secondary, next_goods_nomenclature)
        traverse(goods_nomenclatures, secondary, next_goods_nomenclature)
      end
    end
  end

  def map_goods_nomenclatures(primary, secondary)
    if (heading_map?(primary.reload, secondary.reload) &&
       (primary.producline_suffix < secondary.producline_suffix)) ||
        (primary.number_indents < secondary.number_indents)

      primary.children << secondary unless primary.children.include?(secondary)

      parent_map[secondary.id] = primary
      secondary.parent = primary
      secondary.ancestors += primary.ancestors
      secondary.ancestors << primary
    elsif (heading_map?(primary, secondary) &&
          (primary.producline_suffix == secondary.producline_suffix)) ||
        (!heading_map?(primary, secondary) &&
         primary.number_indents == secondary.number_indents)

      if primary.parent.present? # if primary is not directly under heading
        primary.parent.children << secondary unless primary.parent.children.include?(secondary)

        parent_map[secondary.id] = primary.parent
        secondary.parent = primary.parent
        secondary.ancestors += primary.ancestors
      end
    else (heading_map?(primary, secondary) &&
          (primary.producline_suffix > secondary.producline_suffix)) ||
      (primary.number_indents > secondary.number_indents)

         parent = nth_parent(primary, secondary.number_indents)

         if parent.present?
           parent.children << secondary unless parent.children.include?(secondary)

           parent_map[secondary.id] = parent
           secondary.parent = parent
           secondary.ancestors += parent.ancestors
           secondary.ancestors << parent
         end
    end
  end

  def nth_parent(goods_nomenclature, nth)
    if nth > 0
      goods_nomenclature = goods_nomenclature.parent

      while goods_nomenclature.present? && goods_nomenclature.number_indents >= nth
        goods_nomenclature = parent_of(goods_nomenclature)
      end

      goods_nomenclature
    end
  end

  def parent_of(goods_nomenclature)
    parent_map[goods_nomenclature.id]
  end

  def heading_map?(primary, secondary)
    primary.is_a?(Heading) && secondary.is_a?(Heading)
  end
end
