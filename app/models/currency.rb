class Currency
  TO_SYMBOL = {
    'EUR' => '€',
    'GBP' => '£',
    'EUR (EUC)' => '€',
  }.freeze

  attr_reader :monetary_unit

  def initialize(monetary_unit)
    @monetary_unit = monetary_unit
  end

  def format(duty_amount)
    if TO_SYMBOL.key?(monetary_unit)
      TO_SYMBOL[monetary_unit] + duty_amount
    else
      "#{duty_amount} #{monetary_unit}"
    end
  end
end
