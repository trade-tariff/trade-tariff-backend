module Api
  module V2
    module Measures
      class MeasureConditionPresenter < WrapDelegator
        delegate :excise_alcohol_coercian_starts_from, to: TradeTariffBackend

        ALCOHOLIC_STRENGH_BY_VOLUME_UNIT_CODE = 'ASV'.freeze
        # ASV condition duty amounts on excise measures are presented as
        # 0.01 rather than 1% and need adjusting to be presented as 1%.
        COERCED_ASV_REQUIREMENT_CONVERSION_FACTOR = 100

        def initialize(measure_condition, measure)
          super(measure_condition)

          @measure_condition = measure_condition
          @measure = measure
        end

        def measure_condition_components
          @measure_condition_components ||= MeasureConditionComponentPresenter.wrap(super, measure)
        end

        def condition_duty_amount
          return super if super.blank?

          if apply_coerced_condition_duty_amount_conversion_factor?
            super * COERCED_ASV_REQUIREMENT_CONVERSION_FACTOR
          else
            super
          end
        end

        def duty_expression
          measure_condition_components.map(&:formatted_duty_expression).join(' ')
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

        def requirement
          case requirement_type
          when :document
            "#{certificate_type_description}: #{certificate_description}"
          when :duty_expression
            requirement_duty_expression
          end
        end

        private

        attr_reader :measure, :measure_condition

        def apply_coerced_condition_duty_amount_conversion_factor?
          return false if Time.zone.today < excise_alcohol_coercian_starts_from
          return false if MeasureCondition.point_in_time.present? && MeasureCondition.point_in_time < excise_alcohol_coercian_starts_from

          measure.excise? && asv_requirement?
        end

        def asv_requirement?
          condition_measurement_unit_code == ALCOHOLIC_STRENGH_BY_VOLUME_UNIT_CODE
        end
      end
    end
  end
end
