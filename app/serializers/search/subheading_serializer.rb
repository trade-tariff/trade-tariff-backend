module Search
  class SubheadingSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        id: goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature_item_id,
        goods_nomenclature_sid: goods_nomenclature_sid,
        producline_suffix: producline_suffix,
        validity_start_date: validity_start_date,
        validity_end_date: validity_end_date,
        description: formatted_description,
        number_indents: number_indents,
      }
    end
  end
end
