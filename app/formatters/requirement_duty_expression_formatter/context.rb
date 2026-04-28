RequirementDutyExpressionFormatter::Context = Struct.new(
  :duty_amount,
  :monetary_unit,
  :measurement_unit,
  :measurement_unit_qualifier,
  :measurement_unit_abbreviation,
  :formatted,
  keyword_init: true,
) do
  class << self
    def build(opts)
      measurement_unit = opts[:measurement_unit]
      measurement_unit_qualifier = opts[:formatted_measurement_unit_qualifier]

      new(
        duty_amount: opts[:duty_amount],
        monetary_unit: opts[:monetary_unit_abbreviation].presence || opts[:monetary_unit],
        measurement_unit: measurement_unit,
        measurement_unit_qualifier: measurement_unit_qualifier,
        measurement_unit_abbreviation: measurement_unit.try(
          :abbreviation,
          measurement_unit_qualifier:,
        ),
        formatted: opts[:formatted],
      )
    end
  end
end
