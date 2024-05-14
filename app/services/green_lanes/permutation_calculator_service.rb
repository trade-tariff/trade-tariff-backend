module GreenLanes
  class PermutationCalculatorService
    def initialize(measures)
      @measures = measures
    end

    def call
      @measures.group_by(&method(:permutation_key))
    end

  private

    def permutation_key(measure)
      [
        measure.measure_type_id,
        measure.measure_generating_regulation_id,
        measure.measure_generating_regulation_role,
        measure.geographical_area_id,
        measure.measure_excluded_geographical_areas.map(&:excluded_geographical_area).sort.uniq.join('|'),
        measure.additional_code_type_id,
        measure.additional_code_id,
        measure.measure_conditions.select(&:is_exempting_with_certificate_overridden?).map(&:document_code).sort.uniq.join('|'),
      ]
    end
  end
end
