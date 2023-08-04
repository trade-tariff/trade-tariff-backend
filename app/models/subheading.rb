# Subheading is a special-class of commodity that is non-declarable (acts as a a container of other commodities)
# There are three classes of subheading:
#
# - Harmonised System Subheading (6 digits)
# - Combined Nomenclature Subheading (8 digits)
# - Taric Subheading (10 digits)
class Subheading < GoodsNomenclature
  include TenDigitGoodsNomenclature
  include SearchReferenceable

  def to_admin_param
    to_param
  end

  def to_param
    "#{goods_nomenclature_item_id}-#{producline_suffix}"
  end
end
