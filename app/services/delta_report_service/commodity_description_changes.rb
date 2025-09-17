class DeltaReportService
  class CommodityDescriptionChanges < BaseChanges
    def self.collect(date)
      GoodsNomenclatureDescription
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
      return unless record.goods_nomenclature&.declarable?
      return if record.operation == :create && GoodsNomenclature::Operation.where(goods_nomenclature_sid: record.goods_nomenclature_sid, operation_date: record.operation_date).any?

      TimeMachine.at(record.validity_start_date) do
        {
          type: 'GoodsNomenclatureDescription',
          goods_nomenclature_sid: record.goods_nomenclature_sid,
          date_of_effect:,
          description:,
          change: change || record.description,
        }
      end
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
