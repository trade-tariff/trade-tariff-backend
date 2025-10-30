class TariffChangesService
  class CommodityDescriptionChanges < BaseChanges
    def self.collect(date)
      # Collect updated descriptions for declarable commodities only
      GoodsNomenclatureDescription.operation_klass
        .where(operation_date: date)
        .where(operation: 'U')
        .map { |op_record|
          new(op_record.record, date).analyze if op_record.record.goods_nomenclature&.declarable?
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
