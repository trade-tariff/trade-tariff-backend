module ChangesTablePopulator
  class MeasureDeleted < Importer
    include DescendantPopulator

    def source_table
      :measures_oplog
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
    end

    def where_condition
      { operation: 'D', operation_date: day }
    end

    def change_type
      'measure'
    end
  end
end
