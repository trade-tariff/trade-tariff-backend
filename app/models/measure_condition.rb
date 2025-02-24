class MeasureCondition < Sequel::Model
  CDS_WAIVER_DOCUMENT_CODE = '999L'.freeze
  INCLUDED_NEGATIVE_ACTIONS = %w[08].freeze

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

  one_to_one :appendix_5a,
             key: %i[certificate_type_code certificate_code],
             primary_key: %i[certificate_type_code certificate_code]

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
                                             primary_key: :measure_condition_sid,
                                             order: Sequel.asc(:duty_expression_id)

  delegate :abbreviation, to: :monetary_unit, prefix: true, allow_nil: true
  delegate :description, to: :measurement_unit, prefix: true, allow_nil: true
  delegate :description, to: :measurement_unit_qualifier, prefix: true, allow_nil: true
  delegate :formatted_measurement_unit_qualifier, to: :measurement_unit_qualifier, prefix: false, allow_nil: true
  delegate :description, to: :certificate, prefix: true, allow_nil: true
  delegate :special_nature?, :authorised_use?, to: :certificate, allow_nil: true
  delegate :description, to: :certificate_type, prefix: true, allow_nil: true
  delegate :description, to: :measure_action, prefix: true, allow_nil: true
  delegate :description, to: :measure_condition_code, prefix: true, allow_nil: true
  delegate :measure_condition_class, :threshold_class?, :negative_class?,
           :exemption_class?, :document_class?, to: :classification

  delegate :requirement_operator, to: :measure_condition_code, allow_nil: true

  delegate :guidance_cds, to: :appendix_5a, allow_nil: true

  delegate :positive_action?, to: :measure_action, allow_nil: true

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
      monetary_unit_abbreviation:,
      measurement_unit:,
      formatted_measurement_unit_qualifier:,
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

  def threshold_unit_type
    if is_eps_condition?
      :eps
    elsif is_price_condition?
      :price
    elsif is_weight_condition?
      :weight
    elsif is_volume_condition?
      :volume
    elsif is_percentage_abv_condition?
      :percentage_abv
    end
  end

  def expresses_unit?
    condition_measurement_unit_code.present?
  end

  def universal_waiver_applies?
    document_code.present? && document_code == CDS_WAIVER_DOCUMENT_CODE
  end

  def permutation_key
    if certificate_type_code || certificate_code || condition_duty_amount
      "#{certificate_type_code}-#{certificate_code}-#{condition_duty_amount}"
    else
      measure_condition_sid # ensure always unique
    end
  end

  def unit_for(measure)
    if measure.excise? && expresses_unit?
      {
        measurement_unit_code: condition_measurement_unit_code,
        measurement_unit_qualifier_code: condition_measurement_unit_qualifier_code,
      }
    end
  end

  def is_excluded_condition?
    # Globally exclude the universal waiver conditions
    return true if universal_waiver_applies?
    # Globally exclude all positive conditions
    return false if positive_action?
    # Include conditions that are negative threshold conditions
    return false if is_threshold?
    # Include conditions that are negative with an action code of 08
    return false if action_code.in?(INCLUDED_NEGATIVE_ACTIONS)

    # Exclude conditions that are negative and have no document or threshold
    document_code.blank?
  end

  def is_exempting_with_certificate_overridden?
    (exemption_class? && !is_exempting_certificate_overridden?) || (!exemption_class? && is_exempting_certificate_overridden?)
  end

  private

  def is_threshold?
    condition_duty_amount.present?
  end

  def classification
    @classification ||= MeasureConditionClassification.new(self)
  end

  def is_price_condition?
    condition_monetary_unit_code.present?
  end

  def is_weight_condition?
    MeasurementUnit.weight_units.include? condition_measurement_unit_code
  end

  def is_volume_condition?
    MeasurementUnit.volume_units.include? condition_measurement_unit_code
  end

  def is_percentage_abv_condition?
    MeasurementUnit.percentage_abv_units.include? condition_measurement_unit_code
  end

  def is_eps_condition?
    entry_price_system? && is_price_condition? && is_weight_condition?
  end

  def is_exempting_certificate_overridden?
    certificate.present? && certificate.exempting_certificate_override.present?
  end
end
