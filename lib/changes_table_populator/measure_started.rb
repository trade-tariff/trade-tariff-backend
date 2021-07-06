module ChangesTablePopulator
  class MeasureStarted < Importer
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
            DB[:changes]
              .insert_conflict(constraint: :changes_upsert_unique)
              .import import_fields, integrate_and_find_children(row: element, day: day)
          end
      end

      def where_condition(day: Date.current)
        { validity_start_date: day }
      end

      def change_type
        'measure'
      end

      def action
        'started measures'
      end
    end
  end
end
