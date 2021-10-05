class MeursingMeasureFinderService
  def initialize(root_measure, additional_code_id)
    @root_measure = root_measure
    @additional_code_id = additional_code_id
  end

  def call
    MeursingMeasure.filter(
      additional_code_id: additional_code_id,
      reduction_indicator: root_measure.reduction_indicator,
    )
      .actual
      .eager(
        :measure_excluded_geographical_areas,
        :base_regulation,
        :modification_regulation,
        geographical_area: [:contained_geographical_areas],
        measure_components: [:duty_expression],
      )
      .all
      .select(&:current?)
      .select(&method(:relevant_for_country?))
  end

  private

  attr_reader :root_measure, :additional_code_id

  def relevant_for_country?(measure)
    measure.relevant_for_country?(root_measure.geographical_area_id)
  end
end
