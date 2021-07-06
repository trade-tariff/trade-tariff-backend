module ChangesTablePopulator
  class CommodityCodeDescriptionChanged < Importer
    class << self
      def perform_import(day: Date.current)
        elements = DB[:goods_nomenclature_description_periods]
          .where(where_condition(day: day))
          .select do |row|
            [
              row.goods_nomenclature_item_id,
              row.goods_nomenclature_sid,
              row.productline_suffix,
            ]
          end
        import_records = elements.map { |element| integrate_element(row: element, day: day) }
        DB[:changes]
          .insert_conflict(constraint: :changes_upsert_unique)
          .import import_fields, import_records
      end

      def where_condition(day: Date.current)
        { validity_start_date: day }
      end

      def action
        'started commodity code descriptions'
      end
    end
  end
end
