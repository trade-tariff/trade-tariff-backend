module DutyExpressionPrettifier
  def prettify(float)
    TradeTariffBackend.number_formatter.number_with_precision(
      float,
      minimum_decimal_points: 2,
      precision: 4,
      strip_insignificant_zeros: true,
    )
  end
end
