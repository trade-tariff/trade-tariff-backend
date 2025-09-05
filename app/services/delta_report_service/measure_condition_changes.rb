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
      (record.requirement_type || 'Measure Condition').to_s.humanize&.capitalize
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && record.measure.operation_date == record.operation_date

      @changes = []

      {
        type: 'MeasureCondition',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        additional_code: additional_code(record.measure.additional_code),
        duty_expression: duty_expression(record.measure),
        description:,
        date_of_effect:,
        change:,
      }
    end

    def change
      if record.requirement_type == :document
        "#{record.document_code}: #{record.certificate_description}: #{record.action}"
      elsif record.requirement_type == :duty_expression
        "#{record.last.requirement_duty_expression} : #{record.action}"
      else
        record.action
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
