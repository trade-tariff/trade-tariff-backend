module Api
  module V2
    module Measures
      class DutyExpressionPresenter
        def initialize(measure, declarable)
          @measure = measure
          @declarable = declarable
        end

        def base
          @measure.duty_expression_with_national_measurement_units_for(@declarable)
        end

        def formatted_base
          @measure.formatted_duty_expression_with_national_measurement_units_for(@declarable)
        end

        def verbose_duty
          @measure.verbose_duty_expression_with_national_measurement_units_for(@declarable)
         end

        def id
          "#{@measure.measure_sid}-duty_expression"
        end
      end
    end
  end
end
