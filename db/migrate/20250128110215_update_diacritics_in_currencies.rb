# frozen_string_literal: true

Sequel.migration do
  up do
    ExchangeRateCountryCurrency.where(currency_description: 'Venezuelan Bolívar').update(currency_description: 'Venezuelan Bolivar')
  end
end
