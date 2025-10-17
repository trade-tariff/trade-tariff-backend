class TariffChangesService
  class CommodityDescriptionChanges < BaseChanges
    def self.collect(date)
      # Collect updated commodity descriptions only
      GoodsNomenclatureDescription
        .where(operation_date: date)
        .where(operation: 'U')
        .map { |record|
          new(record, date).analyze if record.goods_nomenclature&.declarable?
        }
        .compact
    end

    def object_name
      'GoodsNomenclatureDescription'
    end

    def object_sid
      record.goods_nomenclature_description_period_sid
    end
  end
end
