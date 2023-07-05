RSpec.describe Api::V2::ExchangeRates::ExchangeRatePeriodSerializer do
  subject(:serializable) { described_class.new(exchange_rate_period).serializable_hash }

  let(:exchange_rate_period) { build(:exchange_rates_period, month: 1, year: 2022) }

  let :expected do
    {
      data: {
        id: exchange_rate_period.id,
        type: :exchange_rate_period,
        attributes: {
          month: 1,
          year: 2022,
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
