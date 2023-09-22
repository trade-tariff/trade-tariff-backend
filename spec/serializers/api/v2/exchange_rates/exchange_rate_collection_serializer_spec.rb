RSpec.describe Api::V2::ExchangeRates::ExchangeRateCollectionSerializer do
  subject(:serializable) { described_class.new(exchange_rate_rates_list).serializable_hash }

  let(:exchange_rate_rates_list) do
    build(
      :exchange_rates_collection,
      :with_rates_file,
      :with_exchange_rates,
    )
  end
  let(:exchange_rate_file) { exchange_rate_rates_list.exchange_rate_files.first }

  let :expected do
    {
      data: {
        id: be_present,
        type: eq(:exchange_rate_collection),
        attributes: {
          year: be_a(Integer),
          month: be_a(Integer),
        },
        relationships: {
          exchange_rate_files: {
            data: [
              { id: be_present, type: eq(:exchange_rate_file) },
            ],
          },
          exchange_rates: {
            data: [
              { id: be_present, type: eq(:exchange_rate) },
            ],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to include_json(expected)
    end
  end
end
