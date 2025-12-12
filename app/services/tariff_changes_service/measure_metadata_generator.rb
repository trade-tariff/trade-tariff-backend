class TariffChangesService
  class MeasureMetadataGenerator
    def self.call(measure_sid)
      new(measure_sid).generate
    end

    def initialize(measure_sid)
      @measure_sid = measure_sid
    end

    def generate
      return {} unless measure

      {
        'measure' => {
          'measure_type_id' => measure.measure_type_id,
          'trade_movement_code' => measure.measure_type.trade_movement_code,
          'geographical_area_id' => measure.geographical_area_id,
          'excluded_geographical_area_ids' => excluded_areas,
          'additional_code' => formatted_additional_code,
        },
      }
    end

    private

    def measure
      @measure ||= begin
        operation_record = Measure.operation_klass
                                  .where(measure_sid: @measure_sid)
                                  .exclude(operation: 'D')
                                  .order(:oid)
                                  .last

        operation_record&.record_from_oplog
      end
    end

    def excluded_areas
      @excluded_areas ||= measure.measure_excluded_geographical_areas_dataset
                                 .select(:excluded_geographical_area)
                                 .map(:excluded_geographical_area)
                                 .sort
    end

    def formatted_additional_code
      ac = measure.additional_code
      ac.present? ? "#{ac.code}: #{ac.description}" : ''
    end
  end
end
