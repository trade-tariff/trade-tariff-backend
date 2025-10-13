class TariffChangesService
  class MeasureChanges < BaseChanges
    def self.collect(date)
      # Use Operation model so we can access deleted records
      Measure.operation_klass
        .where(operation_date: date)
        .map { |record| new(record.record_from_oplog, date).analyze }
        .compact
    end

    def object_name
      'Measure'
    end

    def object_sid
      record.measure_sid
    end

    def excluded_columns
      super + %i[measure_generating_regulation_id justification_regulation_role justification_regulation_id national]
    end
  end
end
