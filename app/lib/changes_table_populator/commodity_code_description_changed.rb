module ChangesTablePopulator
  class CommodityCodeDescriptionChanged < Importer
    class << self
      def source_table
        :goods_nomenclature_description_periods
      end

      def select_condition
        -> { [goods_nomenclature_item_id, goods_nomenclature_sid, productline_suffix] }
      end

      def where_condition(day: Time.zone.today)
        { validity_start_date: day }
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
