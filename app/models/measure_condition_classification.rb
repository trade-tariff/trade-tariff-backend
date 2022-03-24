class MeasureConditionClassification
  DOCUMENT_CLASS = 'document'.freeze
  EXEMPTION_CLASS = 'exemption'.freeze
  THRESHOLD_CLASS = 'threshold'.freeze
  NEGATIVE_CLASS = 'negative'.freeze
  UNKNOWN_CLASS = 'unknown'.freeze

  EXCLUDED_DOCUMENT_CODE_CLASS_DOCUMENT_CODES = [
    '999L', # National Document: CDS universal waiver
    'C084', # Other certificates: Exemption by virtue of Articles 3 and 4 of regulation 2019/2122 (animals intended for scientific purposes, research and diagnostic samples)
  ].freeze

  EXEMPTION_CERTIFICATE_TYPE_CODE = 'Y'.freeze # Particular provisions

  def initialize(measure_condition)
    @measure_condition = measure_condition
  end

  def measure_condition_class
    return THRESHOLD_CLASS if threshold_class?
    return NEGATIVE_CLASS if negative_class?
    return EXEMPTION_CLASS if exemption_class?
    return DOCUMENT_CLASS if document_class?

    UNKNOWN_CLASS
  end

  def threshold_class?
    @measure_condition.condition_duty_amount.present?
  end

  def negative_class?
    @measure_condition.measure_action.present? &&
      @measure_condition.measure_action.negative_action?
  end

  def exemption_class?
    @measure_condition.document_code.present? &&
      @measure_condition.certificate_type_code == EXEMPTION_CERTIFICATE_TYPE_CODE
  end

  def document_class?
    @measure_condition.document_code.present? &&
      !@measure_condition.document_code.in?(EXCLUDED_DOCUMENT_CODE_CLASS_DOCUMENT_CODES)
  end
end
