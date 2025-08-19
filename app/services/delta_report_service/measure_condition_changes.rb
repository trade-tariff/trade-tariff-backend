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
      return if record.operation == :create && record.measure.operation_date == record.operation_date

      {
        type: 'MeasureCondition',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        additional_code: additional_code(record.measure),
        duty_expression: duty_expression(record.measure),
        description:,
        date_of_effect:,
        change: change || '',
      }
    end

    def date_of_effect
      date
    end

    def excluded_columns
      super + %i[component_sequence_number]
    end

    def previous_record
      @previous_record ||= MeasureCondition.operation_klass
                             .where(measure_condition_sid: record.measure_condition_sid)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end
