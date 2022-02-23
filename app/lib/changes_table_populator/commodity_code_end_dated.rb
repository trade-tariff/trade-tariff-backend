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
        elements.map { |element| integrate_element(row: element, day: day) }
      end

      def change_type
        'commodity'
      end
    end
  end
end
