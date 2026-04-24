DutyExpressionFormatter::Context = Struct.new(
  :duty_expression_id,
  :duty_expression_description,
  :duty_expression_abbreviation,
  :duty_amount,
  :monetary_unit,
  :measurement_unit,
  :measurement_unit_qualifier,
  :measurement_unit_abbreviation,
  :measurement_unit_expansion,
  :monetary_unit_to_symbol,
  :resolved_meursing_component,
  :formatted,
  :verbose,
  keyword_init: true,
) do
  class << self
    def build(opts)
      monetary_unit = opts[:monetary_unit_abbreviation].presence || opts[:monetary_unit]
      measurement_unit = opts[:measurement_unit]
      measurement_unit_qualifier = opts[:measurement_unit_qualifier]
      measurement_unit_abbreviation = measurement_unit.try(
        :abbreviation,
        measurement_unit_qualifier:,
      )
      verbose = opts[:verbose]

      measurement_unit_expansion, monetary_unit_to_symbol = verbose_context_values(
        verbose,
        measurement_unit,
        measurement_unit_qualifier,
        monetary_unit,
        opts[:duty_amount],
      )

      new(
        duty_expression_id: opts[:duty_expression_id],
        duty_expression_description: opts[:duty_expression_description],
        duty_expression_abbreviation: opts[:duty_expression_abbreviation],
        duty_amount: opts[:duty_amount],
        monetary_unit: monetary_unit,
        measurement_unit: measurement_unit,
        measurement_unit_qualifier: measurement_unit_qualifier,
        measurement_unit_abbreviation: measurement_unit_abbreviation,
        measurement_unit_expansion: measurement_unit_expansion,
        monetary_unit_to_symbol: monetary_unit_to_symbol,
        resolved_meursing_component: opts[:resolved_meursing],
        formatted: opts[:formatted],
        verbose: verbose,
      )
    end

    private

    def verbose_context_values(verbose, measurement_unit, measurement_unit_qualifier, monetary_unit, duty_amount)
      return [nil, nil] unless verbose

      measurement_unit_expansion = measurement_unit.try(
        :expansion,
        measurement_unit_qualifier:,
      )
      monetary_unit_to_symbol = Currency.new(monetary_unit).try(
        :format,
        DutyExpressionFormatter.prettify(duty_amount).to_s,
      )

      [measurement_unit_expansion, monetary_unit_to_symbol]
    end
  end
end
