class DutyExpressionFormatter::Strategies::Base
  include FormatterOutputHelpers

  def initialize(context)
    @context = context
  end

  private

  attr_reader :context

  def duty_expression_text_fragment
    if context.duty_expression_abbreviation.present?
      context.duty_expression_abbreviation
    elsif context.duty_expression_description.present?
      context.duty_expression_description
    end
  end

  def duty_amount_fragment
    return if context.duty_amount.blank?

    if context.formatted
      formatted_amount_fragment(DutyExpressionFormatter, context.duty_amount, formatted: true)
    elsif context.verbose && context.monetary_unit
      context.monetary_unit_to_symbol
    else
      DutyExpressionFormatter.prettify(context.duty_amount).to_s
    end
  end

  def monetary_or_percent_fragment
    if context.monetary_unit.present? && !context.verbose
      context.monetary_unit
    else
      '%' unless context.monetary_unit
    end
  end

  def default_expression_or_percent_fragment
    if context.duty_expression_abbreviation.present? && context.monetary_unit.blank?
      context.duty_expression_abbreviation
    elsif context.duty_expression_description.present? && context.monetary_unit.blank?
      context.duty_expression_description
    elsif context.duty_expression_description.blank?
      '%'
    end
  end

  def default_monetary_unit_fragment
    context.monetary_unit if context.monetary_unit.present? && !context.verbose
  end

  def measurement_unit_fragment
    render_measurement_unit_fragment(
      **measurement_unit_render_options,
    )
  end

  def per_measurement_unit_fragment
    return if context.measurement_unit_abbreviation.blank?

    render_prefixed_measurement_unit_fragment(
      prefix: '/ ',
      **measurement_unit_render_options,
    )
  end

  def measurement_unit_render_options
    {
      measurement_unit: context.measurement_unit,
      abbreviation: context.measurement_unit_abbreviation,
      formatted: context.formatted,
      unformatted: context.measurement_unit_abbreviation,
      verbose: context.verbose,
      expansion: context.measurement_unit_expansion,
    }
  end
end
