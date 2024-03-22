module Api
  module V2
    module GreenLanes
      class CategoryAssessmentPresenter < SimpleDelegator
        include ContentAddressableId
        attr_reader :measures, :permutation_key

        delegate :geographical_area_id,
                 :geographical_area,
                 :excluded_geographical_area_ids,
                 :excluded_geographical_areas,
                 :exemptions,
                 to: :first_measure

        content_addressable_fields do |ca|
          ca.permutation_key.map(&:to_s).join("\n")
        end

        class << self
          def wrap(category_assessments)
            category_assessments.flat_map do |assessment|
              permutations(assessment).map do |key, measures|
                new assessment, key, measures
              end
            end
          end

          private

          def permutations(assessment)
            ::GreenLanes::PermutationCalculatorService
              .new(assessment.measures)
              .call
          end
        end

        def initialize(category_assessment, permutation_key, measures)
          super(category_assessment)
          @category_assessment = category_assessment
          @permutation_key = permutation_key
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
