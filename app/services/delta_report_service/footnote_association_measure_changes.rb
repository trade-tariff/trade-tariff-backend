class DeltaReportService
  class FootnoteAssociationMeasureChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      # Use Operation model so we can access deleted records
      FootnoteAssociationMeasure::Operation
        .where(operation_date: date)
        .map { |record| new(record.record_from_oplog, date).analyze }
        .compact
    end

    def object_name
      'Footnote'
    end

    def analyze
      return if no_changes?
      return if record.operation == :create && Measure::Operation.where(measure_sid: record.measure_sid, operation_date: record.operation_date, operation: 'C').any?
      return if record.operation == :create && Footnote::Operation.where(footnote_type_id: record.footnote_type_id, footnote_id: record.footnote_id, operation_date: record.operation_date).any?
      return if record.measure.nil? || record.footnote.footnote_description.nil?

      {
        type: 'FootnoteAssociationMeasure',
        measure_sid: record.measure_sid,
        measure_type: measure_type(record.measure),
        import_export: import_export(record.measure),
        geo_area: geo_area(record.measure.geographical_area),
        description:,
        date_of_effect:,
        change: change.present? ? "#{record.footnote.code}: #{change}" : "#{record.footnote.code}: #{record.footnote.description}",
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
