module Cache
  module SearchCacheMethods
    def has_valid_dates(hash, start_key = :validity_start_date, end_key = :validity_end_date)
      hash[start_key].to_date <= as_of &&
        (hash[end_key].nil? || hash[end_key].to_date >= as_of)
    end

    def goods_nomenclature_attributes(goods_nomenclature)
      return nil unless goods_nomenclature.present?

      {
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        number_indents: goods_nomenclature.number_indents,
        formatted_description: goods_nomenclature.formatted_description,
        producline_suffix: goods_nomenclature.producline_suffix,
        validity_start_date: goods_nomenclature.validity_start_date,
        validity_end_date: goods_nomenclature.validity_end_date
      }
    end
  end
end
