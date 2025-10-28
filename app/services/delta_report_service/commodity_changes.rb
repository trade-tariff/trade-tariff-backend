class DeltaReportService
  class CommodityChanges < BaseChanges
    def self.collect(date)
      GoodsNomenclature
        .where(operation_date: date)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Commodity'
    end

    def excluded_columns
      super + %i[path heading_short_code chapter_short_code]
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && !record.declarable? # new non-declarable commodities are not relevant

      {
        type: 'GoodsNomenclature',
        goods_nomenclature_sid: record.goods_nomenclature_sid,
        date_of_effect:,
        description:,
        change: change || record.code,
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
