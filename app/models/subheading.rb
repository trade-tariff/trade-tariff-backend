# Subheading is a special-class of commodity that is non-declarable (acts as a a container of other commodities)
# There are three classes of subheading:
#
# - Harmonised System Subheading (6 digits)
# - Combined Nomenclature Subheading (8 digits)
# - Taric Subheading (10 digits)
class Subheading < Commodity
  set_primary_key [:goods_nomenclature_sid]

  def commodities
    [ancestors, all_children].flatten.compact
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
