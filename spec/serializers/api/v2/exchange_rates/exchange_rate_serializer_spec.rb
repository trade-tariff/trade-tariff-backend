RSpec.describe Api::V2::ExchangeRates::ExchangeRateSerializer do
  subject(:serializable) { described_class.new(exchange_rate).serializable_hash }

  let(:exchange_rate) { build(:exchange_rate) }

  let :expected do
    {
      data: {
        id: exchange_rate.id,
        type: :exchange_rate,
        attributes: {
          country: exchange_rate.country,
          country_code: exchange_rate.country_code,
          currency_description: exchange_rate.currency_description,
          currency_code: exchange_rate.currency_code,
          rate: exchange_rate.rate,
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
