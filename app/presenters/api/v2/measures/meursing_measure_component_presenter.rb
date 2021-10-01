module Api
  module V2
    module Measures
      class MeursingMeasureComponentPresenter < SimpleDelegator
        def formatted_duty_expression
          DutyExpressionFormatter.format(duty_expression_formatter_options)
        end

        private

        def duty_expression_formatter_options
          # There is no possibility of a meursing measure component being at the front of the sequence of components
          # We set the duty expression '04' to mean any expression that comes later in the sequence that is either ad valorem or has measure units
          # and a duty_expression_abbreviation to '+' to indicate that we should concatenate the previous component with the current component as there
          # are multiple.
          super.merge(
            duty_expression_id: '04',
            duty_expression_abbreviation: '+',
            resolved_meursing: true,
            formatted: true,
          )
        end
      end
    end
  end
end
