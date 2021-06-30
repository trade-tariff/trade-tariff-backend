module DeltaTablesGenerator
  class MeasureEndDated < Importer
    class << self
      def perform_import(day: Date.current)
        elements = DB[:measures]
          .where(where_condition(day: day))
          .select do |row|
            [row.goods_nomenclature_item_id, row.goods_nomenclature_sid]
          end
        elements
          .uniq { |element| element[:goods_nomenclature_sid] }
          .each do |element|
            DB[:deltas]
              .insert_conflict(constraint: :deltas_upsert_unique)
              .import import_fields, integrate_and_find_children(row: element, day: day)
          end
      end

      def where_condition(day: Date.current)
        { validity_end_date: day - 1 }
      end

      def delta_type
        'measure'
      end

      def action
        'end-dated measures'
      end
    end
  end
end
