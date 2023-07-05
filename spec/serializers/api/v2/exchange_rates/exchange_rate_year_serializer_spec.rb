RSpec.describe Api::V2::ExchangeRates::ExchangeRateYearSerializer do
  subject(:serializable) { described_class.new(exchange_rate_year).serializable_hash }

  let(:exchange_rate_year) { build(:period_year, year: 2022) }

  let :expected do
    {
      data: {
        id: exchange_rate_year.id,
        type: :exchange_rate_year,
        attributes: {
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
