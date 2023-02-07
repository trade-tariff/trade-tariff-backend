# Subheading is a special-class of commodity that is non-declarable (acts as a a container of other commodities)
# There are three classes of subheading:
#
# - Harmonised System Subheading (6 digits)
# - Combined Nomenclature Subheading (8 digits)
# - Taric Subheading (10 digits)
class Subheading < Commodity
  set_primary_key [:goods_nomenclature_sid]

  include SearchReferenceable

  def to_admin_param
    goods_nomenclature_item_id
  end

  def to_param
    "#{goods_nomenclature_item_id}-#{producline_suffix}"
  end

  def commodities
    @commodities ||= [ancestors, all_children].flatten.compact
  end

  private

  def all_children
    @all_children = []

    traverse_children do |child|
      @all_children << child
    end

    @all_children
  end
end
