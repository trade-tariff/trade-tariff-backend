module Api
  module V2
    module Measures
      class MeasureConditionComponentPresenter < WrapDelegator
        delegate :excise_alcohol_coercian_starts_from, to: TradeTariffBackend

        # Rather than just creating a new measurement unit,
        # Customs Declaration Service (CDS) have opted to multiply the duty amount by 100 to balance
        # the difference between the measurement units of hectoliters and liters.
        #
        # We already have a conversion factor for hectoliters to liters as part of the
        # duty calculator so CDS showing the converted duty amount is actually incorrect.
        #
        # This saves us from treating hectoliters as liters in some special snowflake way.
        COERCED_ASVX_DUTY_AMOUNT_CONVERSION_FACTOR = 0.01

        def initialize(measure_condition_component, measure)
          super(measure_condition_component)

          @measure = measure
        end

        def duty_amount
          return super if super.blank?

          if apply_coerced_duty_amount_conversion_factor?
            super * COERCED_ASVX_DUTY_AMOUNT_CONVERSION_FACTOR
          else
            super
          end
        end

        def formatted_duty_expression
          DutyExpressionFormatter.format(duty_expression_formatter_options.merge(formatted: true))
        end

        def verbose_duty_expression
          DutyExpressionFormatter.format(duty_expression_formatter_options.merge(verbose: true))
        end

        def duty_expression_str
          DutyExpressionFormatter.format(duty_expression_formatter_options)
        end

        private

        attr_reader :measure

        def apply_coerced_duty_amount_conversion_factor?
          return false if Time.zone.today < excise_alcohol_coercian_starts_from
          return false if MeasureCondition.point_in_time.present? && MeasureCondition.point_in_time < excise_alcohol_coercian_starts_from

          measure.excise? && percentage_alcohol_and_volume_per_hl?
        end

        def duty_expression_formatter_options
          {
            duty_expression_id:,
            duty_expression_description:,
            duty_expression_abbreviation:,
            duty_amount:,
            monetary_unit: monetary_unit_code,
            monetary_unit_abbreviation:,
            measurement_unit:,
            measurement_unit_qualifier:,
          }
        end
      end
    end
  end
end
