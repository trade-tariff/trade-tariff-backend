class RequirementDutyExpressionFormatter::OutputBuilder
  include FormatterOutputHelpers

  class << self
    def call(context)
      new(context).call
    end
  end

  def initialize(context)
    @context = context
  end

  def call
    [amount_fragment, unit_fragment].compact
  end

  private

  attr_reader :context

  def amount_fragment
    return if context.duty_amount.blank?

    formatted_amount_fragment(
      RequirementDutyExpressionFormatter,
      context.duty_amount,
      formatted: context.formatted,
    )
  end

  def unit_fragment
    if monetary_measurement_qualifier?
      monetary_measurement_qualifier_fragment
    elsif monetary_measurement?
      monetary_measurement_fragment
    elsif measurement_only?
      measurement_fragment
    elsif monetary_only?
      context.monetary_unit.to_s
    end
  end

  def monetary_measurement_qualifier?
    context.monetary_unit.present? && context.measurement_unit_abbreviation.present? && context.measurement_unit_qualifier.present?
  end

  def monetary_measurement?
    context.monetary_unit.present? && context.measurement_unit_abbreviation.present?
  end

  def measurement_only?
    context.measurement_unit_abbreviation.present?
  end

  def monetary_only?
    context.monetary_unit.present?
  end

  def monetary_measurement_qualifier_fragment
    if context.formatted
      "#{context.monetary_unit} / (#{measurement_unit_abbr_tag(context.measurement_unit, context.measurement_unit_abbreviation)} / #{context.measurement_unit_qualifier})"
    else
      "#{context.monetary_unit} / (#{context.measurement_unit} / #{context.measurement_unit_qualifier})"
    end
  end

  def monetary_measurement_fragment
    if context.formatted
      "#{context.monetary_unit} / #{measurement_unit_abbr_tag(context.measurement_unit, context.measurement_unit_abbreviation)}"
    else
      "#{context.monetary_unit} / #{context.measurement_unit}"
    end
  end

  def measurement_fragment
    if context.formatted
      measurement_unit_abbr_tag(context.measurement_unit, context.measurement_unit_abbreviation)
    else
      context.measurement_unit
    end
  end
end
