module DeltaTablesGenerator
  class CommodityCodeStarted < Importer
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
        DB[:deltas].import import_fields, import_records
      end

      def where_condition(day: Date.current)
        { validity_start_date: day }
      end

      def action
        'started commodity codes'
      end
    end
  end
end
