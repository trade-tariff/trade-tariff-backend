class DeltaReportService
  class MeasureConditionChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      MeasureCondition
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      (record.requirement_type || 'Measure Condition').to_s.titleize
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && Measure::Operation.where(measure_sid: record.measure_sid, operation_date: record.operation_date).any?

      @changes = []

      {
        type: 'MeasureCondition',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        additional_code: additional_code(record.measure.additional_code),
        description:,
        date_of_effect:,
        change:,
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end

    def change
      if record.requirement_type == :document
        "#{record.document_code}: #{record.certificate_description}"
      elsif record.requirement_type == :duty_expression
        "#{record.last.requirement_duty_expression}: #{record.action}"
      else
        "#{record.measure_condition_code_description}: #{record.action}"
      end
    end

    def date_of_effect
      date
    end

    def excluded_columns
      super + %i[component_sequence_number]
    end
  end
end
