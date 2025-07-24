module ChangesTablePopulator
  class MyottCommodityDescriptionChanged < MyottChangesImporter
    def source_table
      :goods_nomenclature_description_periods
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid, validity_start_date, validity_end_date] }
    end

    def where_condition
      { operation_date: day }
    end

    def change_type
      'commodity description changed'
    end
  end
end
