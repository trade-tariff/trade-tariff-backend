# Subheading is a special-class of commodity that is non-declarable (acts as a a container of other commodities)
# There are three classes of subheading:
#
# - Harmonised System Subheading (6 digits)
# - Combined Nomenclature Subheading (8 digits)
# - Taric Subheading (10 digits)
class Subheading < Commodity
  set_primary_key [:goods_nomenclature_sid]

  one_to_many :search_references, key: %i[referenced_id productline_suffix], primary_key: %i[code producline_suffix], reciprocal: :referenced, conditions: { referenced_class: 'Subheading' },
                                  adder: proc { |search_reference| search_reference.update(referenced_id: code, productline_suffix: producline_suffix, referenced_class: 'Subheading') },
                                  remover: proc { |search_reference| search_reference.update(referenced_id: nil, referenced_class: nil, productline_suffix: nil) },
                                  clearer: proc { search_references_dataset.update(referenced_id: nil, referenced_class: nil, productline_suffix: nil) } do |dataset|
                                    dataset.where(productline_suffix: producline_suffix)
                                  end

  def to_param
    "#{goods_nomenclature_item_id}-#{producline_suffix}"
  end

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
