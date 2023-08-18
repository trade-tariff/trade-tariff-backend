RSpec.describe Api::V2::ExchangeRates::ExchangeRateSerializer do
  subject(:serializable) { described_class.new(presented).serializable_hash }

  let(:presented) do
    exchange_rate_currency_rate = create(:exchange_rate_currency_rate, currency_code: 'GBP')
    create(:exchange_rate_currency, currency_code: 'GBP', currency_description: 'Pound Sterling')

    Api::V2::ExchangeRates::CurrencyRatePresenter.new(exchange_rate_currency_rate, 6, 2023)
  end

  let(:expected) do
    {
      data: {
        id: presented.id,
        type: :exchange_rate,
        attributes: {
          currency_description: 'Pound Sterling',
          currency_code: 'GBP',
          rate: presented.rate,
          validity_start_date: presented.validity_start_date,
          validity_end_date: presented.validity_end_date,
        },
        relationships: { exchange_rate_countries: { data: [] } },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql(expected)
    end
  end
end
