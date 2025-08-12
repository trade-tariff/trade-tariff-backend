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
      return if record.operation == :update && changes.empty?

      {
        type: 'GeographicalArea',
        geographical_area_id: geo_area(record),
        date_of_effect: date_of_effect,
        description: description,
        change: change || geo_area(record),
      }
    end

    def previous_record
      @previous_record ||= GeographicalArea.operation_klass
                             .where(geographical_area_id: record.geographical_area_id)
                             .where(Sequel.lit('oid < ?', record.oid))
                             .order(Sequel.desc(:oid))
                             .first
    end
  end
end
