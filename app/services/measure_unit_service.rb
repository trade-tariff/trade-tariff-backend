class MeasureUnitService
  def initialize(measures)
    @measures = measures
  end

  def call
    units.each_with_object({}) do |unit, acc|
      unit_code = unit[:measurement_unit_code]
      unit_qualifier_code = unit[:measurement_unit_qualifier_code]
      unit_key = "#{unit_code}#{unit_qualifier_code}"

      MeasurementUnit.units(unit_code, unit_key).map do |presented_unit|
        # For some measurement units we can replace the presented unit with one or more other units. This means our unit key is now different to the root unit
        key = "#{presented_unit['measurement_unit_code']}#{presented_unit['measurement_unit_qualifier_code']}"

        acc[key] = presented_unit
      end
    end
  end

  private

  attr_reader :measures

  def units
    @units ||= measures.select(&:expresses_unit?).flat_map(&:units)
  end
end
