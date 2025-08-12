class DeltaReportService
  class MeasureComponentChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      MeasureComponent
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Measure Component'
    end

    def analyze
      return if record.operation == :create && record.measure.operation_date == record.operation_date
      return if record.operation == :update && changes.empty?

      {
        type: 'MeasureComponent',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        additional_code: additional_code(record.measure),
        duty_expression: duty_expression(record.measure),
        description:,
        date_of_effect:,
        change: change || duty_expression(record),
      }
    end

    def date_of_effect
      date
    end

    def previous_record
      @previous_record ||= MeasureComponent.operation_klass
                             .where(measure_sid: record.measure_sid)
                             .where(duty_expression_id: record.duty_expression_id)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end
