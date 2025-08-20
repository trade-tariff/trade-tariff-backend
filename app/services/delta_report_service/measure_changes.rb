class DeltaReportService
  class MeasureChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      Measure
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Measure'
    end

    def excluded_columns
      super + %i[measure_generating_regulation_id justification_regulation_role justification_regulation_id]
    end

    def analyze
      return if no_changes?

      {
        type: 'Measure',
        goods_nomenclature_item_id: record.goods_nomenclature_item_id,
        validity_start_date: record.validity_start_date,
        validity_end_date: record.validity_end_date,
        measure_type: measure_type(record),
        import_export: import_export(record),
        geo_area: geo_area(record.geographical_area),
        additional_code: additional_code(record.additional_code),
        duty_expression: duty_expression(record),
        description:,
        date_of_effect:,
        change: change || measure_type(record),
      }
    end

    def previous_record
      @previous_record ||= Measure.operation_klass
                             .where(measure_sid: record.measure_sid)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end
