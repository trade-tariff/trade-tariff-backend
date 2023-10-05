RSpec.describe Api::V2::ExchangeRates::ExchangeRateSerializer do
  subject(:serializable) { described_class.new(exchange_rate).serializable_hash }

  let(:exchange_rate) do
    create(:exchange_rate_currency_rate, :with_usa)

    ExchangeRateCurrencyRate.with_exchange_rate_country_currency.take
  end

  let(:expected) do
    {
      data: {
        id: exchange_rate.id.to_s,
        type: :exchange_rate,
        attributes: {
          country: 'United States',
          country_code: 'US',
          currency_description: 'Dollar',
          currency_code: 'USD',
          rate: exchange_rate.presented_rate,
          validity_start_date: exchange_rate.validity_start_date,
          validity_end_date: exchange_rate.validity_end_date,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql(expected)
    end
  end
end
