class RequirementDutyExpressionFormatter
  class << self
    def prettify(float)
      TradeTariffBackend.number_formatter.number_with_precision(
        float,
        precision: 4,
        minimum_decimal_points: 2,
        strip_insignificant_zeros: true,
      )
    end

    def format(opts = {})
      context = Context.build(opts)

      OutputBuilder.call(context).join(' ').html_safe
    end
  end
end
