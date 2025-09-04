class DeltaReportService
  class FootnoteAssociationMeasureChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      FootnoteAssociationMeasure
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
      return if record.operation == :create && record.measure.operation_date == record.operation_date
      return if record.operation == :create && record.footnote.operation_date == record.operation_date

      {
        type: 'FootnoteAssociationMeasure',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        additional_code: additional_code(record.measure.additional_code),
        duty_expression: duty_expression(record.measure),
        description:,
        date_of_effect:,
        change: change.present? ? "#{record.footnote.code}: #{change}" : record.footnote.code,
      }
    end

    def date_of_effect
      date
    end
  end
end
