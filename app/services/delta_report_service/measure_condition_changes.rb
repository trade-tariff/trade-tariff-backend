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
      'Measure Condition'
    end

    def analyze
      return if no_changes?
      return if record.is_excluded_condition?
      return if record.operation == :create && Measure::Operation.where(measure_sid: record.measure_sid, operation_date: record.operation_date).any?

      @changes = []

      {
        type: 'MeasureCondition',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
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
        TimeMachine.at(record.certificate&.validity_start_date || date) do
          "#{record.document_code}: #{record.certificate_description}: #{record.measure_action_description}"
        end
      else
        "No document provided: #{record.measure_action_description} #{record.requirement_duty_expression}"
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
