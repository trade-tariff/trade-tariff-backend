class DeltaReportService
  class CommodityChanges < BaseChanges
    def self.collect(date)
      GoodsNomenclature
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Commodity'
    end

    def analyze
      return if no_changes?

      {
        type: 'GoodsNomenclature',
        goods_nomenclature_item_id: record.goods_nomenclature_item_id,
        date_of_effect:,
        description:,
        change: change || record.code,
      }
    end

    def previous_record
      @previous_record ||= GoodsNomenclature.operation_klass
                             .where(goods_nomenclature_sid: record.goods_nomenclature_sid)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end
