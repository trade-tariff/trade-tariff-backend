module ChangesTablePopulator
  class MeasureCreatedOrUpdated < Importer
    class << self
      def source_table
        :measures
      end

      def select_condition
        -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
      end

      def where_condition(day: Time.zone.today)
        Sequel.lit('validity_start_date <= ? AND ' \
                   '(validity_end_date IS NULL OR validity_end_date > ?) AND ' \
                   'operation IN (\'C\', \'U\') AND ' \
                   'operation_date = ?', day, day, day)
      end

      def import_records(elements:, day: Time.zone.today)
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
