module ChangesTablePopulator
  class CommodityCodeEndDated < Importer
    class << self
      def perform_import(day: Date.current)
        elements = DB[:goods_nomenclatures]
          .where(where_condition(day: day))
          .select do |row|
            [
              row.goods_nomenclature_item_id,
              row.goods_nomenclature_sid,
              row.producline_suffix,
            ]
          end
        import_records = elements.map { |element| integrate_element(row: element, day: day) }
        DB[:changes]
          .insert_conflict(constraint: :changes_upsert_unique)
          .import import_fields, import_records
      end

      def where_condition(day: Date.current)
        { validity_end_date: day - 1.day }
      end

      def action
        'end-dated commodity codes'
      end
    end
  end
end
