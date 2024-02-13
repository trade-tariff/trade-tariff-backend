module GreenLanes
  class FindCategoryAssessmentsService
    class << self
      def call(goods_nomenclature:, geographical_area_id: nil)
        goods_nomenclature.applicable_measures.flat_map { |measure|
          CategoryAssessment.filter(regulation_id: measure.measure_generating_regulation_id,
                                    measure_type_id: measure.measure_type_id,
                                    geographical_area: geographical_area_id)
        }.uniq(&:id)
      end
    end
  end
end
