class DeltaReportService
  class FootnoteAssociationGoodsNomenclatureChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      FootnoteAssociationGoodsNomenclature
        .where(operation_date: date)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Footnote'
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && GoodsNomenclature::Operation.where(goods_nomenclature_sid: record.goods_nomenclature_sid, operation_date: record.operation_date).any?
      return if record.operation == :create && Footnote::Operation.where(footnote_type_id: record.footnote_type, footnote_id: record.footnote_id, operation_date: record.operation_date).any?

      {
        type: 'FootnoteAssociationGoodsNomenclature',
        goods_nomenclature_sid: record.goods_nomenclature.goods_nomenclature_sid,
        description:,
        date_of_effect:,
        change: change.present? ? "#{record.footnote.code}: #{change}" : "#{record.footnote.code}: #{record.footnote.description}",
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
