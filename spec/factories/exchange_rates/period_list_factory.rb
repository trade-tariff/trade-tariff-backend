FactoryBot.define do
  factory :period_list, class: 'ExchangeRates::PeriodList' do
    year { 2020 }
    exchange_rate_periods { [] }
    exchange_rate_years { [] }
  end
end
