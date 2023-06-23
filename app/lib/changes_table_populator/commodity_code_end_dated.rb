module ChangesTablePopulator
  class CommodityCodeEndDated < Importer
    def source_table
      :goods_nomenclatures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix] }
    end

    def where_condition
      previous_day = (day - 1.day)

      { validity_end_date: (previous_day.beginning_of_day..previous_day.end_of_day) }
    end

    def change_type
      'commodity'
    end
  end
end
