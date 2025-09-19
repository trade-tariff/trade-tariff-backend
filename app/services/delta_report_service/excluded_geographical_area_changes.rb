class DeltaReportService
  class ExcludedGeographicalAreaChanges < BaseChanges
    def self.collect(date)
      # Use Operation model so we can access deleted records
      MeasureExcludedGeographicalArea::Operation
        .where(operation_date: date)
        .map { |record| new(record.record_from_oplog, date).analyze }
        .compact
    end

    def object_name
      'Excluded Geo Area'
    end

    def analyze
      measures = Measure::Operation.where(measure_sid: record.measure_sid, operation_date: record.operation_date, operation: 'U')

      return unless measures.any?

      TimeMachine.at(record.operation_date) do
        {
          type: 'ExcludedGeographicalArea',
          measure_sid: record.measure_sid,
          measure_type: measure_type(record.measure),
          import_export: import_export(record.measure),
          geo_area: geo_area(record.geographical_area, record.measure.excluded_geographical_areas),
          date_of_effect: date,
          description:,
          change: "Excluded #{record.excluded_geographical_area}",
        }
      end
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
