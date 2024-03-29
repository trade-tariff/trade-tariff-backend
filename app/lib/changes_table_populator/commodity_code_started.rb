module ChangesTablePopulator
  class CommodityCodeStarted < Importer
    def source_table
      :goods_nomenclatures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix] }
    end

    def where_condition
      { validity_start_date: day }
    end

    def change_type
      'commodity'
    end
  end
end
