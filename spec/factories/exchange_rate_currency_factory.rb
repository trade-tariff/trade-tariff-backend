FactoryBot.define do
  factory :exchange_rate_currency do
    currency_code { 'AED' }
    currency_description { 'Dirham' }
    spot_rate_required { nil }
  end
end
