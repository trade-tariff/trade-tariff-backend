class MeasureUnitService
  def initialize(measures)
    @measures = measures
  end

  def call
    units.each_with_object({}) do |unit, acc|
      unit_key = "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier_code]}"

      if acc[unit_key].blank?
        acc[unit_key] = {}
        acc[unit_key] = MeasurementUnit.measurement_unit(unit_key)
      end
    end
  end

  private

  attr_reader :measures

  def units
    @units ||= measures.select(&:expresses_unit?).flat_map(&:units)
  end
end
