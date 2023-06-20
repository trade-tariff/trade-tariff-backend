module ChangesTablePopulator
  class CommodityCodeStarted < Importer
    class << self
      def source_table
        :goods_nomenclatures
      end

      def select_condition
        -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix] }
      end

      def where_condition(day: Time.zone.today)
        { validity_start_date: day }
      end

      def import_records(elements:, day: Time.zone.today)
        elements.map do |element|
          build_change_record(row: element,
                              day:,
                              is_end_line: end_line?(row: element, day:))
        end
      end

      def change_type
        'commodity'
      end
    end
  end
end
