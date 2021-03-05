class MeasureUnitService
  def initialize(measures)
    @measures = measures
  end

  def call
    units.each_with_object({}) do |unit, acc|
      unit_key = "#{unit['measurement_unit_code']}#{unit['measurement_unit_qualifier_code']}"

      if acc[unit_key].present?
        acc[unit_key]['measure_sids'].add(unit['measure_sid'])

        next
      end

      acc[unit_key] = MeasurementUnit.measurement_units[unit_key]
      acc[unit_key]['measure_sids'] = Set.new([unit['measure_sid']])
    end
  end

  private

  attr_reader :measures

  def units
    @units ||= measures.select(&:expresses_unit?).flat_map do |measure|
      measure.measure_component_units + measure.measure_condition_units
    end
  end
end
