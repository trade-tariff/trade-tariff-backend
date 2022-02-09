module Api
  module V2
    module Headings
      class OverviewMeasurePresenter < SimpleDelegator
        def initialize(measure, commodity)
          @measure = measure
          @commodity = commodity

          super measure
        end

        def vat
          vat?
        end

        def duty_expression_id
          "#{measure_sid}-duty_expression"
        end

        def duty_expression
          Hashie::TariffMash.new(
            id: duty_expression_id,
            base: duty_expression_with_national_measurement_units_for(@commodity),
            formatted_base: formatted_duty_expression_with_national_measurement_units_for(@commodity),
          )
        end

        def effective_start_date
          super&.strftime('%FT%T.%LZ')
        end

        def effective_end_date
          super&.strftime('%FT%T.%LZ')
        end
      end
    end
  end
end
