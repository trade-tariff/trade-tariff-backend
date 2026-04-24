class DutyExpressionFormatter
  class << self
    def prettify(float)
      TradeTariffBackend.number_formatter.number_with_precision(
        float,
        minimum_decimal_points: 2,
        precision: 4,
        strip_insignificant_zeros: true,
      )
    end

    def format(opts = {})
      context = Context.build(opts)
      output = OutputBuilder.call(context)

      result = output.join(' ').html_safe

      if context.resolved_meursing_component
        "<strong>#{result}</strong>"
      else
        result
      end
    end
  end
end
