module ChangesTablePopulator
  class MeasureDeleted < Importer
    class << self
      def source_table
        :measures_oplog
      end

      def select_condition
        -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
      end

      def where_condition(day: Date.current)
        { operation: 'D', operation_date: day }
      end

      def import_records(elements:, day: Date.current)
        elements
          .uniq { |element| element[:goods_nomenclature_sid] }
          .collect_concat { |element| integrate_and_find_children(row: element, day: day) }
      end

      def change_type
        'measure'
      end
    end
  end
end
