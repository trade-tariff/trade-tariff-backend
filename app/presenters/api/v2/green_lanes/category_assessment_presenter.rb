# There is a One to Many mapping between Category Assessments and their Presented
# versions
#
# This is because we include exemptions and geographical areas in the serialized
# category assessments but they can vary depending upon the measures
#
# This means the presented versions get hashed ids including the various params
# used for their differentation (the 'permutation key')
module Api
  module V2
    module GreenLanes
      class CategoryAssessmentPresenter < SimpleDelegator
        include ContentAddressableId
        attr_reader :measures, :permutation_key

        delegate :geographical_area_id,
                 :geographical_area,
                 :excluded_geographical_areas,
                 :measure_conditions,
                 :measure_sid,
                 to: :first_measure

        content_addressable_fields do |ca|
          ca.permutation_key.map(&:to_s).join("\n")
        end

        class << self
          def wrap(category_assessments)
            Array.wrap(category_assessments).flat_map do |assessment|
              permutations(assessment).map do |key, measures|
                new assessment, key, measures
              end
            end
          end

          private

          def permutations(assessment)
            ::GreenLanes::PermutationCalculatorService
              .new(assessment.combined_measures)
              .call
          end
        end

        def initialize(category_assessment, permutation_key, measures)
          super(category_assessment)
          @category_assessment = category_assessment
          @permutation_key = permutation_key
          @measures = MeasurePresenter.wrap(measures)
        end

        def theme_id
          theme&.code
        end

        def measure_ids
          @measure_ids = measures.map(&:measure_sid)
        end

        def category_assessment_id
          @category_assessment.id
        end

        def excluded_geographical_area_ids
          excluded_geographical_areas.map(&:geographical_area_id)
        end

        def exemptions
          @exemptions ||= (certificates + additional_codes + pseudo_exemptions)
        end

        def certificates
          certificates = measure_conditions
            .select(&:is_exempting_with_certificate_overridden?)
            .map(&:certificate)
            .uniq

          MeasureConditionPermutations::GreenLanesCalculator.new(measure_conditions, certificates, measure_sid)
                                                    .group_certificates

        end

        def additional_codes
          additional_codes = measures.map(&:additional_code).compact
          additional_codes.select { |ad| ad.exempting_additional_code_override.present? }
        end

        def pseudo_exemptions
          ExemptionPresenter.wrap(@category_assessment.exemptions)
        end

        def regulation
          RegulationPresenter.new(super)
        end

      private

        def first_measure
          measures.first
        end
      end
    end
  end
end
