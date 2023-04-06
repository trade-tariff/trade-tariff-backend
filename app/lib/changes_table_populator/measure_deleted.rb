module ChangesTablePopulator
  class MeasureDeleted < Importer
    def source_table
      :measures_oplog
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
    end

    def where_condition
      { operation: 'D', operation_date: day }
    end

    def build_all_change_records(source_changes)
      source_changes
        .uniq { |element| element[:goods_nomenclature_sid] }
        .collect_concat do |source_change|
          build_descendant_change_records(row: source_change, day:)
        end
    end

    def change_type
      'measure'
    end
  end
end
