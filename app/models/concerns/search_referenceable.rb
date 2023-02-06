module SearchReferenceable
  extend ActiveSupport::Concern

  included do
    adder = proc { |search_reference| search_reference.update(goods_nomenclature_sid:, referenced_class: name) }
    remover = proc { |search_reference| search_reference.update(goods_nomenclature_sid: nil, referenced_class: nil) }
    clearer = proc { search_references_dataset.update(goods_nomenclature_sid: nil, referenced_class: nil) }

    one_to_many :search_references,
                key: :goods_nomenclature_sid,
                reciprocal: :referenced,
                conditions: { referenced_class: name },
                adder:,
                remover:,
                clearer:
  end
end
