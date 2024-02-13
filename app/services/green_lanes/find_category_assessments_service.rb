module GreenLanes
  class FindCategoryAssessmentsService
    class << self
      def call(goods_nomenclature:, geographical_area_id: nil)
        CategoryAssessment.all.map { |category_assessment|
          matches = goods_nomenclature.applicable_measures.select do |measure|
            category_assessment.match?(regulation_id: measure.measure_generating_regulation_id,
                                       measure_type_id: measure.measure_type_id,
                                       geographical_area: geographical_area_id)
          end

          matches.any? ? [category_assessment, matches] : nil
        }.compact
      end
    end
  end
end
