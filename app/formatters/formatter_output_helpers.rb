module FormatterOutputHelpers
  private

  def formatted_amount_fragment(formatter_class, amount, formatted:)
    prettified_amount = formatter_class.prettify(amount).to_s
    return prettified_amount unless formatted

    "<span>#{prettified_amount}</span>"
  end

  def measurement_unit_abbr_tag(measurement_unit, abbreviation)
    "<abbr title='#{measurement_unit.description}'>#{abbreviation}</abbr>"
  end

  def render_measurement_unit_fragment(measurement_unit:, abbreviation:, formatted:, unformatted:, verbose: false, expansion: nil)
    if formatted
      measurement_unit_abbr_tag(measurement_unit, abbreviation)
    elsif verbose && expansion.present?
      expansion
    else
      unformatted
    end
  end

  def render_prefixed_measurement_unit_fragment(prefix:, measurement_unit:, abbreviation:, formatted:, unformatted:, verbose: false, expansion: nil)
    "#{prefix}#{render_measurement_unit_fragment(
      measurement_unit: measurement_unit,
      abbreviation: abbreviation,
      formatted: formatted,
      unformatted: unformatted,
      verbose: verbose,
      expansion: expansion,
    )}"
  end
end
