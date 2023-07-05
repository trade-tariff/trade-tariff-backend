FactoryBot.define do
  factory :period_list, class: 'ExchangeRates::PeriodList' do
    year { 2020 }
    exchange_rate_periods { [] }
    exchange_rate_years { [] }
  end

  trait :with_period_years do
    exchange_rate_years { build_list :period_year, 1 }
  end

  trait :with_periods do
    exchange_rate_periods { build_list :exchange_rates_period, 1 }
  end
end
