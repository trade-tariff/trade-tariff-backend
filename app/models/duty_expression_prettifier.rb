module DutyExpressionPrettifier
  NUMBER_FORMATTER = NumberFormatter.new.freeze

  def prettify(float)
    NUMBER_FORMATTER.number_with_precision(
      float,
      minimum_decimal_points: 2,
      precision: 4,
      strip_insignificant_zeros: true,
    )
  end
end
