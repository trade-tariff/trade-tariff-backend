module Api
  module V2
    module Measures
      class MeasureConditionPresenter < WrapDelegator
        ALCOHOL_PERCENTAGE_MEASUREMENT_UNIT_CODE = 'ASV'.freeze
        # ASV condition duty amounts on excise measures are presented as
        # 0.01 rather than 1% and need adjusting to be presented as 1%.
        COERCED_ASV_REQUIREMENT_CONVERSION_FACTOR = 100

        def initialize(measure, measure_condition)
          super(measure_condition)

          @measure = measure
          @measure_condition = measure_condition
        end

        def measure_condition_components
          @measure_condition_components ||= MeasureConditionComponentPresenter.wrap(measure, super)
        end

        def condition_duty_amount
          return super unless apply_coerced_condition_duty_amount_conversion_factor?
          return super if super.blank?

          super * COERCED_ASV_REQUIREMENT_CONVERSION_FACTOR
        end

        def requirement_duty_expression
          RequirementDutyExpressionFormatter.format(
            duty_amount: condition_duty_amount,
            monetary_unit: condition_monetary_unit_code,
            monetary_unit_abbreviation:,
            measurement_unit:,
            formatted_measurement_unit_qualifier:,
            formatted: true,
          )
        end

        def self.wrap(measure, measure_conditions)
          measure_conditions.map do |measure_condition|
            new(measure, measure_condition)
          end
        end

        private

        attr_reader :measure, :measure_condition

        def requirement
          case requirement_type
          when :document
            "#{certificate_type_description}: #{certificate_description}"
          when :duty_expression
            requirement_duty_expression
          end
        end

        def apply_coerced_condition_duty_amount_conversion_factor?
          measure.excise? && asv_requirement?
        end

        def asv_requirement?
          condition_measurement_unit_code == ALCOHOL_PERCENTAGE_MEASUREMENT_UNIT_CODE
        end
      end
    end
  end
end
