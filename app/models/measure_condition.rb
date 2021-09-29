class MeasureCondition < Sequel::Model
  plugin :time_machine
  plugin :national
  plugin :oplog, primary_key: :measure_condition_sid

  set_primary_key [:measure_condition_sid]

  one_to_one :measure, key: :measure_sid,
                       primary_key: :measure_sid

  one_to_one :measure_action, primary_key: :action_code,
                              key: :action_code do |ds|
    ds.with_actual(MeasureAction)
  end

  one_to_one :certificate, key: %i[certificate_type_code certificate_code],
                           primary_key: %i[certificate_type_code certificate_code] do |ds|
    ds.with_actual(Certificate)
  end

  one_to_one :certificate_type, key: :certificate_type_code,
                                primary_key: :certificate_type_code do |ds|
    ds.with_actual(CertificateType)
  end

  one_to_one :measurement_unit, primary_key: :condition_measurement_unit_code,
                                key: :measurement_unit_code do |ds|
    ds.with_actual(MeasurementUnit)
  end

  one_to_one :monetary_unit, primary_key: :condition_monetary_unit_code,
                             key: :monetary_unit_code do |ds|
    ds.with_actual(MonetaryUnit)
  end

  one_to_one :measurement_unit_qualifier, primary_key: :condition_measurement_unit_qualifier_code,
                                          key: :measurement_unit_qualifier_code do |ds|
    ds.with_actual(MeasurementUnitQualifier)
  end

  one_to_one :measure_condition_code, key: :condition_code,
                                      primary_key: :condition_code do |ds|
    ds.with_actual(MeasureConditionCode)
  end

  one_to_many :measure_condition_components, key: :measure_condition_sid,
                                             primary_key: :measure_condition_sid

  delegate :abbreviation, to: :monetary_unit, prefix: true, allow_nil: true
  delegate :description, to: :measurement_unit, prefix: true, allow_nil: true
  delegate :description, to: :measurement_unit_qualifier, prefix: true, allow_nil: true
  delegate :formatted_measurement_unit_qualifier, to: :measurement_unit_qualifier, prefix: false, allow_nil: true
  delegate :description, to: :certificate, prefix: true, allow_nil: true
  delegate :description, to: :certificate_type, prefix: true, allow_nil: true
  delegate :description, to: :measure_action, prefix: true, allow_nil: true
  delegate :description, to: :measure_condition_code, prefix: true, allow_nil: true

  def before_create
    self.measure_condition_sid ||= self.class.next_national_sid

    super
  end

  def document_code
    "#{certificate_type_code}#{certificate_code}"
  end

  def measure_condition_component_ids
    measure_condition_components.map { |mcc| mcc.pk.join('-') }
  end

  # TODO: presenter?
  def requirement
    case requirement_type
    when :document
      "#{certificate_type_description}: #{certificate_description}"
    when :duty_expression
      requirement_duty_expression
    end
  end

  def requirement_duty_expression
    RequirementDutyExpressionFormatter.format(
      duty_amount: condition_duty_amount,
      monetary_unit: condition_monetary_unit_code,
      monetary_unit_abbreviation: monetary_unit_abbreviation,
      measurement_unit: measurement_unit,
      formatted_measurement_unit_qualifier: formatted_measurement_unit_qualifier,
      currency: TradeTariffBackend.currency,
      formatted: true,
    )
  end

  def action
    measure_action_description
  end

  def condition
    "#{condition_code}: #{measure_condition_code_description}"
  end

  def requirement_type
    if certificate_code.present?
      :document
    elsif condition_duty_amount.present?
      :duty_expression
    end
  end

  def duty_expression
    measure_condition_components.map(&:formatted_duty_expression).join(' ')
  end

  def ad_valorem?
    measure_condition_components.count == 1 && measure_condition_components.first.ad_valorem?
  end

  def entry_price_system?
    condition_code == MeasureConditionCode::ENTRY_PRICE_SYSTEM_CODE
  end

  def expresses_unit?
    measure_condition_components.any?(&:expresses_unit?)
  end

  def units
    measure_condition_components.map(&:unit)
  end
end
