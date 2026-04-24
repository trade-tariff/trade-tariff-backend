class DutyExpressionFormatter::Strategies::Default < DutyExpressionFormatter::Strategies::Base
  def call
    [
      duty_amount_fragment,
      default_expression_or_percent_fragment,
      default_monetary_unit_fragment,
      per_measurement_unit_fragment,
    ].compact
  end
end
