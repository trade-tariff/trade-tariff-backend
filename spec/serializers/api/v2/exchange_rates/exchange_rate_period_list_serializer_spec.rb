RSpec.describe Api::V2::ExchangeRates::ExchangeRatePeriodListSerializer do
  subject(:serializable) { described_class.new(exchange_rate_period_list).serializable_hash }

  let(:exchange_rate_period_list) { build(:period_list, :with_periods, :with_period_years) }
  let(:exchange_rate_period) { exchange_rate_period_list.exchange_rate_periods.first }
  let(:exchange_rate_year) { exchange_rate_period_list.exchange_rate_years.first }

  let :expected do
    {
      data: {
        id: exchange_rate_period_list.id,
        type: :exchange_rate_period_list,
        attributes: {
          year: exchange_rate_period_list.year,
          type: 'scheduled',
        },
        relationships: {
          exchange_rate_periods: {
            data: [
              {
                id: exchange_rate_period.id,
                type: :exchange_rate_period,
              },
            ],
          },
          exchange_rate_years: {
            data: [
              {
                id: exchange_rate_year.id,
                type: :exchange_rate_year,
              },
            ],
          },
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
