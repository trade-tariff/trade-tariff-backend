module Cache
  module SearchCacheMethods
    def has_valid_dates(hash)
      hash[:validity_start_date].to_date <= as_of &&
        (hash[:validity_end_date].nil? || hash[:validity_end_date].to_date >= as_of)
    end

    def goods_nomenclature_attributes(goods_nomenclature)
      return nil if goods_nomenclature.blank?

      {
        id: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_class: goods_nomenclature.goods_nomenclature_class,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        number_indents: goods_nomenclature.number_indents,
        description: goods_nomenclature.description,
        formatted_description: goods_nomenclature.formatted_description,
        producline_suffix: goods_nomenclature.producline_suffix,
        validity_start_date: goods_nomenclature.validity_start_date,
        validity_end_date: goods_nomenclature.validity_end_date,
      }
    end

    def geographical_area_attributes(geographical_area)
      return nil if geographical_area.blank?

      {
        id: geographical_area.geographical_area_id,
        geographical_area_id: geographical_area.geographical_area_id,
        description: geographical_area.description,
      }
    end
  end
end
