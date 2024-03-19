module Api
  module V2
    module GreenLanes
      class CategoryAssessmentPresenter < SimpleDelegator
        attr_reader :measures

        delegate :geographical_area_id,
                 :geographical_area,
                 :excluded_geographical_area_ids,
                 :excluded_geographical_areas,
                 :exemptions,
                 to: :first_measure

        class << self
          def wrap(category_assessments)
            category_assessments.flat_map do |assessment|
              assessment.measure_permutations.map do |_key, permutation|
                new assessment, permutation
              end
            end
          end
        end

        def initialize(category_assessment, measures)
          super(category_assessment)
          @category_assessment = category_assessment
          @measures = MeasurePresenter.wrap(measures)
        end

        def measure_ids
          @measure_ids = measures.map(&:measure_sid)
        end

        def theme
          @category_assessment.theme.theme
        end

        def category
          @category_assessment.theme.category
        end

      private

        def first_measure
          measures.first
        end
      end
    end
  end
end
