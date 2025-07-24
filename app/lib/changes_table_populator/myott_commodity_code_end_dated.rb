module ChangesTablePopulator
  class MyottCommodityCodeEndDated < MyottChangesImporter
    def source_table
      :goods_nomenclatures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix, validity_start_date, validity_end_date] }
    end

    def where_condition
      Sequel.expr(operation_date: day.beginning_of_day..day.end_of_day) &
        Sequel.expr { validity_end_date !~ nil }
    end

    def change_type
      'commodity end dated'
    end
  end
end
