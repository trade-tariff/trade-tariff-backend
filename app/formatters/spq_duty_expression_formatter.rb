class SpqDutyExpressionFormatter
  class << self
    def format(component)
      duty_amount = prettify(component.duty_amount)

      "(£#{duty_amount} - SPR discount) / vol% / hl"
    end

    def prettify(float)
      TradeTariffBackend.number_formatter.number_with_precision(
        float,
        minimum_decimal_points: 2,
        precision: 4,
        strip_insignificant_zeros: true,
      )
    end
  end
end
