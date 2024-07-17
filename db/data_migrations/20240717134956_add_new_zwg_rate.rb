# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      zig_currency = ExchangeRateCountryCurrency.where(country_description: 'Zimbabwe',currency_code: 'ZIG',country_code:'ZW').first
      zig_currency.update(validity_end_date: Date.new(2024, 07, 01))
      zig_currency.save

      ExchangeRateCountryCurrency.create(country_description: 'Zimbabwe',
                                         currency_code: 'ZWG',
                                         country_code:'ZW',
                                         currency_description: 'Zimbabwe Gold',
                                         validity_start_date: Date.new(2024,07,31),
                                         validity_end_date: nil,)

    end
  end

  down do
    # We don't want to rollback to incorrect Zimbabwe rates.
  end
end
