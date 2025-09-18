class DeltaReportService
  class MeasureComponentChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      MeasureComponent
        .where(operation_date: date)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      record.measure.supplementary? ? 'Supplementary Unit' : 'Duty Expression'
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && Measure::Operation.where(measure_sid: record.measure_sid, operation_date: record.operation_date).any?

      {
        type: 'MeasureComponent',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        description:,
        date_of_effect:,
        change: change || duty_expression(record.measure),
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end

    def date_of_effect
      date
    end
  end
end
