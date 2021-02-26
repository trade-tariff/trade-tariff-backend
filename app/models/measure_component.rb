class MeasureComponent < Sequel::Model
  include Formatter

  plugin :time_machine
  plugin :oplog, primary_key: %i[measure_sid duty_expression_id]
  plugin :conformance_validator

  set_primary_key %i[measure_sid duty_expression_id]

  one_to_one :duty_expression, key: :duty_expression_id,
                               primary_key: :duty_expression_id do |ds|
    ds.with_actual(DutyExpression)
  end

  one_to_one :measurement_unit, key: :measurement_unit_code,
                                primary_key: :measurement_unit_code do |ds|
    ds.with_actual(MeasurementUnit)
  end

  one_to_one :monetary_unit, key: :monetary_unit_code,
                             primary_key: :monetary_unit_code do |ds|
    ds.with_actual(MonetaryUnit)
  end

  one_to_one :measurement_unit_qualifier, key: :measurement_unit_qualifier_code,
                                          primary_key: :measurement_unit_qualifier_code do |ds|
    ds.with_actual(MeasurementUnitQualifier)
  end

  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid

  delegate :description, :abbreviation, to: :duty_expression, prefix: true
  delegate :abbreviation, to: :monetary_unit, prefix: true, allow_nil: true
  delegate :description, to: :monetary_unit, prefix: true, allow_nil: true

  def formatted_duty_expression
    return '' if measure.measure_type_id.in?(%w(DDA DDJ))
    DutyExpressionFormatter.format(duty_expression_formatter_options.merge(formatted: true))
  end

  def duty_expression_str
    return '' if measure.measure_type_id.in?(%w(DDA DDJ))
    DutyExpressionFormatter.format(duty_expression_formatter_options)
  end

  def meursing?
    duty_expression_id.in?(DutyExpression::MEURSING_DUTY_EXPRESSION_IDS)
  end

  def zero_duty?
    duty_amount&.zero?
  end

  private

  def duty_expression_formatter_options
    {
      duty_expression_id: duty_expression_id,
      duty_expression_description: duty_expression_description,
      duty_expression_abbreviation: duty_expression_abbreviation,
      duty_amount: duty_amount,
      monetary_unit: monetary_unit_code,
      monetary_unit_abbreviation: monetary_unit_abbreviation,
      measurement_unit: measurement_unit,
      measurement_unit_qualifier: measurement_unit_qualifier,
      currency: TradeTariffBackend.currency,
      excise: measure.excise?
    }
  end
end
