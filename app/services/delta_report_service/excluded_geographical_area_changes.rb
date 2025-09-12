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
      return if Measure::Operation.where(measure_sid: record.measure_sid, operation_date: record.operation_date).any?

      {
        type: 'ExcludedGeographicalArea',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.geographical_area),
        date_of_effect: date,
        description:,
        change: "Excluded #{record.excluded_geographical_area}",
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
