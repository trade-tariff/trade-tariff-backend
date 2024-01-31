module GreenLanes
  class FindCategoryAssessmentsService
    def call(goods_nomenclature)
      goods_nomenclature.applicable_measures.flat_map do |measure|
        CategoryAssessment.filter(regulation_id: measure.measure_generating_regulation_id,
                                  measure_type_id: measure.measure_type_id)
      end
    end
  end
end
