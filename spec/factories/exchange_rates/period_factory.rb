FactoryBot.define do
  factory :exchange_rates_period, class: 'ExchangeRates::Period' do
    month { 1 }
    year { 2022 }
    files { [] }
  end
end
