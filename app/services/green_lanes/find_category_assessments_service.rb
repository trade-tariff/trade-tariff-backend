module GreenLanes
  class FindCategoryAssessmentsService

    FILTERED_CATEGORY = Set.new([1, 2]).freeze
    class << self
      def call(goods_nomenclature:, geographical_area_id: nil)
        new(goods_nomenclature, geographical_area_id).call
      end
    end

    def initialize(goods_nomenclature, geographical_area_id)
      @goods_nomenclature = goods_nomenclature
      @geographical_area_id = geographical_area_id
    end

    def call
      CategoryAssessmentJson.all
                            .map(&method(:presented_matching_assessment))
                            .compact
    end

  private

    def assessment_matches_measure?(category_assessment, measure)
      category_assessment.match?(regulation_id: measure.measure_generating_regulation_id,
                                 measure_type_id: measure.measure_type_id,
                                 geographical_area: @geographical_area_id,
                                 filtered_category: FILTERED_CATEGORY)
    end

    def matching_measures(category_assessment)
      @goods_nomenclature.applicable_measures.select do |measure|
        assessment_matches_measure?(category_assessment, measure)
      end
    end

    def presented_matching_assessment(category_assessment)
      matches = matching_measures(category_assessment)
      return if matches.empty?

      ::Api::V2::GreenLanes::CategoryAssessmentPresenter.new(category_assessment, matches)
    end
  end
end
