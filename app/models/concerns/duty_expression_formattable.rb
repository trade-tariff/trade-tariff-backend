module DutyExpressionFormattable
  def duty_expression_formatter_options
    {
      duty_expression_id:,
      duty_expression_description:,
      duty_expression_abbreviation:,
      duty_amount:,
      monetary_unit: monetary_unit_code,
      monetary_unit_abbreviation:,
      measurement_unit:,
      measurement_unit_qualifier:,
    }
  end

  def formatted_duty_expression
    DutyExpressionFormatter.format(duty_expression_formatter_options.merge(formatted: true))
  end

  def verbose_duty_expression
    DutyExpressionFormatter.format(duty_expression_formatter_options.merge(verbose: true))
  end

  def duty_expression_str
    DutyExpressionFormatter.format(duty_expression_formatter_options)
  end
end
