class DeltaReportService
  class GeographicalAreaChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      GeographicalArea
        .where(operation_date: date)
        .order(:oid)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Geo Area'
    end

    def analyze
      return if no_changes?

      {
        type: 'GeographicalArea',
        geographical_area_id: geo_area(record),
        date_of_effect: date_of_effect,
        description: description,
        change: change || geo_area(record),
      }
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
