class TariffChangesService
  class CommodityChanges < BaseChanges
    def self.collect(date)
      GoodsNomenclature.operation_klass
        .where(operation_date: date)
        .map { |op_record|
          next unless op_record.record&.declarable?

          new(op_record.record, date).analyze
        }
        .compact
    end

    def object_name
      'Commodity'
    end

    def object_sid
      record.goods_nomenclature_sid
    end

    def excluded_columns
      super + %i[path heading_short_code chapter_short_code]
    end
  end
end
