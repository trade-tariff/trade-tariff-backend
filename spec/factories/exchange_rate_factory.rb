FactoryBot.define do
  factory :exchange_rate do
    id { 'CAD' }
    rate { Forgery(:monetary).money.to_f }
    base_currency { 'EUR' }
    applicable_date { Date.current.iso8601 }

    initialize_with do
      new(
        id: id,
        rate: rate,
        base_currency: base_currency,
        applicable_date: applicable_date,
      )
    end
  end
end
