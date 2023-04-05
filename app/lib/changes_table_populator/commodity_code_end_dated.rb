module ChangesTablePopulator
  class CommodityCodeEndDated < Importer
    class << self
      def source_table
        :goods_nomenclatures
      end

      def select_condition
        -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix] }
      end

      def where_condition(day: Time.zone.today)
        { validity_end_date: day - 1.day }
      end

      def import_records(elements:, day: Time.zone.today)
        elements.map do |element|
          last_valid_day = (day - 1.day).beginning_of_day
          declarable_on_last_day = end_line?(row: element, day: last_valid_day)

          integrate_element(row: element, day:, is_end_line: declarable_on_last_day)
        end
      end

      def change_type
        'commodity'
      end
    end
  end
end
