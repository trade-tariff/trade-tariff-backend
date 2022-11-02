class Currency
  TO_SYMBOL = {
    'EUR' => '€',
    'GBP' => '£',
  }.freeze

  def self.to_symbol(monetary_unit, duty_amount)
    TO_SYMBOL[monetary_unit] + duty_amount.to_s
  end
end
