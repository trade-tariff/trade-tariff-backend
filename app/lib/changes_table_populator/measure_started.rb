module ChangesTablePopulator
  class MeasureStarted < Importer
    class << self
      def source_table
        :measures
      end

      def select_condition
        -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
      end

      def where_condition(day: Time.zone.today)
        { validity_start_date: day }
      end

      def import_records(elements:, day: Time.zone.today)
        elements
          .uniq { |element| element[:goods_nomenclature_sid] }
          .collect_concat { |element| integrate_and_find_children(row: element, day:) }
      end

      def change_type
        'measure'
      end
    end
  end
end
