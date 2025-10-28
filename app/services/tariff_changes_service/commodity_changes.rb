class TariffChangesService
  class CommodityChanges < BaseChanges
    def self.collect(date)
      GoodsNomenclature
        .where(operation_date: date)
        .map { |record|
          new(record, date).analyze if record.declarable?
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
