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
    meursing_measures.find do |meursing_measure|
      meursing_measure.measure_type_id == root_measure_component.duty_expression.meursing_measure_type_id
    end
  end
end
