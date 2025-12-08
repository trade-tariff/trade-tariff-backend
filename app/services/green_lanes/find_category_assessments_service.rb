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
        .select(&method(:filter_by_category_assessments))
        .select(&method(:filter_by_geographical_area))
        .group_by(&method(:category_assessments))
        .flat_map do |assessments, measures_for_assessment|
          assessments.flat_map do |assessment|
            compute_assessment_permutations(assessment, measures_for_assessment)
          end
        end
    end

  private

    def compute_assessment_permutations(assessment, assessment_measures)
      permutations_for_assessment(assessment_measures)
        .map do |key, measure_permutation|
          present_assessment(assessment, key, measure_permutation)
        end
    end

    def permutations_for_assessment(assessment_measures)
      PermutationCalculatorService.new(assessment_measures).call
    end

    def present_assessment(assessment, key, measure_permutation)
      ::Api::V2::GreenLanes::CategoryAssessmentPresenter
        .new(assessment, key, measure_permutation)
    end

    def category_assessments(measure)
      assessments = measure.try(:category_assessment).presence || measure.try(:category_assessments)

      Array.wrap(assessments)
    end

    def filter_by_category_assessments(measure)
      category_assessments(measure).any?
    end

    def filter_by_geographical_area(measure)
      return true if @geographical_area_id.blank?

      measure.relevant_for_country?(@geographical_area_id) || measure.relevant_for_country?('GB')
    end
  end
end
