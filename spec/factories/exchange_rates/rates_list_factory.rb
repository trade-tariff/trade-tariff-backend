FactoryBot.define do
  factory :rates_list, class: 'ExchangeRates::RatesList' do
    year { 2020 }
    month { 6 }
    exchange_rate_files { [] }
    exchange_rates { [] }
  end

  trait :with_rates_file do
    exchange_rate_files { build_list :exchange_rate_file, 1 }
  end

  trait :with_exchange_rates do
    exchange_rates { build_list :exchange_rate, 1 }
  end
end
