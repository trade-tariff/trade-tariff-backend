class DeltaReportService
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

    def excluded_columns
      super + %i[measure_generating_regulation_id justification_regulation_role justification_regulation_id national]
    end

    def analyze
      return if no_changes?

      {
        type: 'Measure',
        goods_nomenclature_item_id: record.goods_nomenclature_item_id,
        validity_start_date: record.validity_start_date,
        validity_end_date: record.validity_end_date,
        measure_type: measure_type(record),
        import_export: import_export(record),
        geo_area: geo_area(record.geographical_area, record.excluded_geographical_areas),
        description:,
        date_of_effect:,
        change: change || measure_type(record),
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
