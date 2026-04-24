class DutyExpressionFormatter::Strategies::DescriptionAmount < DutyExpressionFormatter::Strategies::Base
  def call
    [
      duty_expression_text_fragment,
      duty_amount_fragment,
      monetary_or_percent_fragment,
      per_measurement_unit_fragment,
    ].compact
  end
end
