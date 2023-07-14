class MeasureConditionComponent < Sequel::Model
  plugin :oplog, primary_key: %i[measure_condition_sid
                                 duty_expression_id]

  set_primary_key %i[measure_condition_sid duty_expression_id]

  one_to_one :measure_condition, key: :measure_condition_sid,
                                 primary_key: :measure_condition_sid

  include Componentable

  def formatted_duty_expression
    DutyExpressionFormatter.format(
      duty_expression_id:,
      duty_expression_description:,
      duty_expression_abbreviation:,
      duty_amount:,
      monetary_unit: monetary_unit_code,
      monetary_unit_abbreviation:,
      measurement_unit:,
      measurement_unit_qualifier:,
      currency: TradeTariffBackend.currency,
      formatted: true,
    )
  end
end
