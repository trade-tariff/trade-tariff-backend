class MeursingMeasureComponentResolverService
  def initialize(root_measure, meursing_measures)
    @root_measure = root_measure
    @meursing_measures = meursing_measures
  end

  def call
    # Iterate root measure components and replace placeholder meursing components with meursing measure answer components
    root_measure.measure_components.map do |root_measure_component|
      if root_measure_component.meursing?
        meursing_component_for(root_measure_component)
      else
        root_measure_component
      end
    end
  end

  private

  attr_reader :root_measure, :meursing_measures

  def meursing_component_for(root_measure_component)
    applicable_measures = meursing_measures.select do |meursing_measure|
      meursing_measure.measure_type_id == root_measure_component.duty_expression.meursing_measure_type_id
    end

    # Occasionally we get multiple meursing measures that apply to multiple geographical areas based on the contained geographical area logic. We should aim to retrieve the most specific answer if possible
    most_specific_measure = applicable_measures.find do |meursing_measure|
      meursing_measure.geographical_area_id == root_measure.geographical_area_id
    end

    applicable_measure = most_specific_measure.presence || applicable_measures.first

    return nil unless applicable_measure

    # Meursing measures only ever have a single component
    component = applicable_measure.measure_components.first

    Api::V2::Measures::MeursingMeasureComponentPresenter.new(component)
  end
end
