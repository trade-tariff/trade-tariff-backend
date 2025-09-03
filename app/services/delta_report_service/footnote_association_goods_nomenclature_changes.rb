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
      "Footnote #{record.footnote.code}"
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
        change: change,
      }
    end

    def previous_record
      @previous_record ||= FootnoteAssociationGoodsNomenclature.operation_klass
                             .where(goods_nomenclature_sid: record.goods_nomenclature_sid, footnote_id: record.footnote_id, footnote_type: record.footnote_type)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end
