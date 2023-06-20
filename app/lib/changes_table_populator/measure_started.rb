module ChangesTablePopulator
  class MeasureStarted < Importer
    include DescendantPopulator

    def source_table
      :measures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
    end

    def where_condition
      { validity_start_date: day }
    end

    def change_type
      'measure'
    end
  end
end
