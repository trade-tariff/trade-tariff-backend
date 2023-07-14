class MeasureComponent < Sequel::Model
  plugin :oplog, primary_key: %i[measure_sid duty_expression_id]

  set_primary_key %i[measure_sid duty_expression_id]

  include Componentable

  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid

  def id
    pk.join('-')
  end

  alias_method :measurement_unit_id, :measurement_unit_code
  alias_method :measurement_unit_qualifier_id, :measurement_unit_qualifier_code

  def formatted_duty_expression
    DutyExpressionFormatter.format(duty_expression_formatter_options.merge(formatted: true))
  end

  def verbose_duty_expression
    DutyExpressionFormatter.format(duty_expression_formatter_options.merge(verbose: true))
  end

  def duty_expression_str
    DutyExpressionFormatter.format(duty_expression_formatter_options)
  end

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
      currency: TradeTariffBackend.currency,
    }
  end
end
