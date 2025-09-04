class DeltaReportService
  class FootnoteAssociationGoodsNomenclatureChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      FootnoteAssociationGoodsNomenclature
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Footnote'
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && record.goods_nomenclature.operation_date == record.operation_date
      return if record.operation == :create && record.footnote.operation_date == record.operation_date

      {
        type: 'FootnoteAssociationGoodsNomenclature',
        goods_nomenclature_item_id: record.goods_nomenclature.goods_nomenclature_item_id,
        description:,
        date_of_effect:,
        change: change.present? ? "#{record.footnote.code}: #{change}" : record.footnote.code,
      }
    end
  end
end
