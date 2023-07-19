module Api
  module V2
    module Measures
      class MeasureConditionComponentPresenter < WrapDelegator
        # Sadly, rather than just creating a new measurement unit,
        # CDS have opted to multiply the duty amount by 100 to balance
        # the difference between the measurement units of hectoliters and liters.
        #
        # We already have a conversion factor for hectoliters to liters as part of the
        # duty calculator so CDS showing the converted duty amount is very confusing.
        #
        # This saves us from treating hectoliters as liters in some special snowflake way.
        #
        # The coercian only happened for excise duties, on the first measure component
        # of alcohol measures.
        COERCED_ASVX_DUTY_AMOUNT_CONVERSION_FACTOR = 0.01

        def initialize(measure, measure_condition_component, index)
          super(measure_condition_component)

          @measure = measure
          @measure_condition_component = measure_condition_component
          @index = index
        end

        def duty_amount
          return super unless apply_coerced_duty_amount_conversion_factor?
          return super if super.blank?

          super * COERCED_ASVX_DUTY_AMOUNT_CONVERSION_FACTOR
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

        def self.wrap(measure, measure_condition_components)
          measure_condition_components.each_with_index.map do |measure_condition_component, index|
            new(measure, measure_condition_component, index)
          end
        end

        private

        attr_reader :measure, :measure_condition_component, :index

        def apply_coerced_duty_amount_conversion_factor?
          index.zero? && measure.excise? && measure.has_alcohol_measurement_units?
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
