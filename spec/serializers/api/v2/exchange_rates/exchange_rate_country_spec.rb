RSpec.describe Api::V2::ExchangeRates::ExchangeRateCountrySerializer do
  subject(:serializable) { described_class.new(exchange_rate_country).serializable_hash }

  let(:exchange_rate_country) do
    build(
      :exchange_rate_country,
      country_code: 'UK',
      currency_code: 'GBP',
      country: 'United Kingdom',
    )
  end

  let(:expected) do
    {
      data: {
        id: 'UK',
        type: :exchange_rate_country,
        attributes: {
          currency_code: 'GBP',
          country_code: 'UK',
          country: 'United Kingdom',
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
