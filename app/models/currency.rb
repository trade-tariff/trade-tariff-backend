class Currency
  TO_SYMBOL = {
    'EUR' => '€',
    'GBP' => '£',
  }.freeze

  attr_reader :monetary_unit

  def initialize(monetary_unit)
    @monetary_unit = monetary_unit
  end

  def format(duty_amount)
    TO_SYMBOL[monetary_unit] + duty_amount
  end
end
