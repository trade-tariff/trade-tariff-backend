class DeltaReportService
  class GeographicalAreaChanges < BaseChanges
    include MeasurePresenter

    def self.collect(date)
      GeographicalArea
        .where(operation_date: date)
        .map { |record| new(record, date).analyze }
        .compact
    end

    def object_name
      'Geo Area'
    end

    def analyze
      return if no_changes?

      TimeMachine.at(record.validity_start_date) do
        {
          type: 'GeographicalArea',
          geographical_area_sid: record.geographical_area_sid,
          date_of_effect: date_of_effect,
          description: description,
          change: change || geo_area(record),
        }
      end
    rescue StandardError => e
      Rails.logger.error "Error with #{object_name} OID #{record.oid}"
      raise e
    end
  end
end
