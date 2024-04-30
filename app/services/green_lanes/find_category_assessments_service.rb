module GreenLanes
  class FindCategoryAssessmentsService
    class << self
      def call(measures, geographical_area_id = nil)
        new(measures, geographical_area_id).call
      end
    end

    def initialize(measures, geographical_area_id = nil)
      @measures = measures
      @geographical_area_id = geographical_area_id
    end

    def call
      @measures
        .select(&:category_assessment)
        .select(&method(:filter_by_geographical_area))
        .group_by(&:category_assessment)
        .flat_map do |assessment, measures_for_assessment|
          compute_assessment_permutations(assessment, measures_for_assessment)
        end
    end

  private

    def compute_assessment_permutations(assessment, assessment_measures)
      permutations_for_assessment(assessment_measures)
        .map do |key, permutation|
          present_assessment(assessment, key, permutation)
        end
    end

    def permutations_for_assessment(assessment_measures)
      PermutationCalculatorService.new(assessment_measures).call
    end

    def present_assessment(assessment, key, permutation)
      ::Api::V2::GreenLanes::CategoryAssessmentPresenter
        .new(assessment, key, permutation)
    end

    def filter_by_geographical_area(measure)
      return true if @geographical_area_id.blank?

      measure.relevant_for_country? @geographical_area_id
    end
  end
end
