class MeasureUnitService
  def initialize(measures)
    @measures = measures
  end

  def call
    units.each_with_object({}) do |unit, acc|
      unit_key = "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier_code]}"
      component_id = unit[:component_id]
      condition_component_id = unit[:condition_component_id]

      if acc[unit_key].present?
        acc[unit_key]['component_ids'].add(component_id) if component_id
        acc[unit_key]['condition_component_ids'].add(condition_component_id) if condition_component_id
      else
        acc[unit_key] = {}
        acc[unit_key] = MeasurementUnit.measurement_unit(unit_key)
        acc[unit_key]['component_ids'] = Set.new([component_id].compact)
        acc[unit_key]['condition_component_ids'] = Set.new([condition_component_id].compact)
      end
    end
  end

  private

  attr_reader :measures

  def units
    @units ||= measures.select(&:expresses_unit?).flat_map(&:units)
  end
end
