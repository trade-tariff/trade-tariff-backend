class DeltaReportService
  class ExcludedGeographicalAreaChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      MeasureExcludedGeographicalArea
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Excluded Geo Area'
    end

    def analyze
      return if record.measure.operation_date == record.operation_date

      {
        type: 'ExcludedGeographicalArea',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.geographical_area),
        additional_code: additional_code(record.measure.additional_code),
        duty_expression: duty_expression(record.measure),
        date_of_effect: date,
        description: 'Excluded geo area',
        change: "Excluded #{record.excluded_geographical_area}",
      }
    end
  end
end
