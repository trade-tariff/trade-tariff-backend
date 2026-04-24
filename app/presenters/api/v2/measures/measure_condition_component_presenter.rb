module Api
  module V2
    module Measures
      class MeasureConditionComponentPresenter < WrapDelegator
        include DutyExpressionFormattable

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

        def presented_duty_expression
          if small_producers_quotient?
            verbose_duty_expression
          else
            formatted_duty_expression
          end
        end

        private

        attr_reader :measure

        def apply_coerced_duty_amount_conversion_factor?
          return false if point_in_time.present? && point_in_time < excise_alcohol_coercian_starts_from

          measure.excise? && percentage_alcohol_and_volume_per_hl?
        end
      end
    end
  end
end
