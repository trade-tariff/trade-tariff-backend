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
end
