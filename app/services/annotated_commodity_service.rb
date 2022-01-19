# Walk the commodities of a heading/subheading (assumed to be ordered correctly)
# and annotate them with whether they are a leaf (have no children) and
# with the id of their parent goods_nomenclature
#
# This is then consumed by the frontend tariff application to easily build a tree UI for perusal
# of headings, subheadings and declarable commodities.
class AnnotatedCommodityService
  def initialize(heading)
    @heading = heading
  end

  def call
    traverse(@heading.commodities.first)

    @heading
  end

  private

  # TODO: Why can't we just iterate through a list of commodities in pairs and stamp them according to the conditions in map_goods_nomenclatures  method?
  def traverse(current_goods_nomenclature)
    # ignore case when first goods_nomenclature is blank it's a direct child of the heading
    if @heading.commodities.index(current_goods_nomenclature).present?
      next_goods_nomenclature = @heading.commodities[@heading.commodities.index(current_goods_nomenclature) + 1]

      if next_goods_nomenclature.present? # we are not at the end of the goods_nomenclature array
        map_goods_nomenclatures(current_goods_nomenclature, next_goods_nomenclature)

        traverse(next_goods_nomenclature)
      end
    end
  end

  def map_goods_nomenclatures(primary, secondary)
    if primary.number_indents < secondary.number_indents
      primary.leaf = false
      secondary.parent_sid = primary.goods_nomenclature_sid
      parent_map[secondary.goods_nomenclature_sid] = primary.goods_nomenclature_sid
    elsif primary.number_indents == secondary.number_indents
      if primary.parent_sid.present? # if primary is not directly under heading
        parent = find_commodity(primary.parent_sid)
        parent.leaf = false
        secondary.parent_sid = parent.goods_nomenclature_sid
        parent_map[secondary.goods_nomenclature_sid] = parent.goods_nomenclature_sid
      end
    else
      parent = nth_parent(primary, secondary.number_indents)

      if parent.present?
        parent.leaf = false
        secondary.parent_sid = parent.goods_nomenclature_sid
        parent_map[secondary.goods_nomenclature_sid] = parent.goods_nomenclature_sid
      end
    end
  end

  def nth_parent(goods_nomenclature, nth)
    if nth.positive?
      goods_nomenclature = find_commodity(goods_nomenclature.parent_sid)

      goods_nomenclature = parent_of(goods_nomenclature) while goods_nomenclature.present? && goods_nomenclature.number_indents >= nth

      goods_nomenclature
    end
  end

  def parent_of(goods_nomenclature)
    find_commodity(parent_map[goods_nomenclature.goods_nomenclature_sid])
  end

  def find_commodity(goods_nomenclature_sid)
    index = commodity_index[goods_nomenclature_sid]
    @heading.commodities[index] if index.present?
  end

  def parent_map
    @parent_map ||= {}
  end

  def commodity_index
    @commodity_index ||= begin
      unmerged_index = @heading.commodities.each_with_index.map do |commodity, index|
        { commodity.goods_nomenclature_sid => index }
      end

      unmerged_index.reduce({}, :merge)
    end
  end
end
