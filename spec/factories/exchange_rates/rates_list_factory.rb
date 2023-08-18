FactoryBot.define do
  factory :exchange_rates_list, class: 'ExchangeRates::RatesList' do
    year { 2023 }
    month { 6 }
    publication_date { '2023-06-22T00:00:00.000Z' }
    exchange_rate_files { [] }
    exchange_rates { [] }
  end

  trait :with_rates_file do
    exchange_rate_files do
      build_list(
        :exchange_rate_file,
        1,
        period_month: month,
        period_year: year,
      )
    end
  end

  trait :with_exchange_rates do
    exchange_rates do
      start_of_month = Time.zone.parse("#{year}-#{month}-01").beginning_of_month

      create_list(
        :exchange_rate_currency_rate,
        1,
        validity_start_date: start_of_month,
      )
    end
  end
end
