module DeltaTablesGenerator
  class MeasureCreatedOrUpdated < Importer
    class << self
      def perform_import(day: Date.current)
        elements = DB[:measures]
          .where(where_condition(day: day))
          .select do |row|
            [row.goods_nomenclature_item_id, row.goods_nomenclature_sid]
          end
        elements.each do |element|
          DB[:deltas].import import_fields, integrate_and_find_children(row: element, day: day)
        end
      end

      def where_condition(day: Date.current)
        Sequel.lit('validity_start_date <= ? AND ' \
                   '(validity_end_date IS NULL OR validity_end_date > ?) AND ' \
                   'operation IN (\'C\', \'U\') AND ' \
                   'operation_date = ?', day, day, day)
      end

      def delta_type
        'measure'
      end

      def action
        'created or updated measures'
      end
    end
  end
end
