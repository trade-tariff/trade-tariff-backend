class MeursingMeasureFinderService
  def initialize(root_measure, additional_code_id)
    @root_measure = root_measure
    @additional_code_id = additional_code_id
  end

  def call
    MeursingMeasure.filter(
      additional_code_id: additional_code_id,
      geographical_area_id: root_measure.geographical_area_id,
      reduction_indicator: root_measure.reduction_indicator,
    )
      .actual
      .eager(measure_components: [:duty_expression])
      .all
      .select(&:current?)
  end

  private

  attr_reader :root_measure, :additional_code_id
end
