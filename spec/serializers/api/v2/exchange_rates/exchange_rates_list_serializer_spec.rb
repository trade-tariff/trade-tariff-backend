RSpec.describe Api::V2::ExchangeRates::ExchangeRatesListSerializer do
  subject(:serializable) { described_class.new(exchange_rate_rates_list).serializable_hash }

  let(:exchange_rate_rates_list) { build(:exchange_rates_list, :with_rates_file, :with_exchange_rates) }
  let(:exchange_rate_file) { exchange_rate_rates_list.exchange_rate_files.first }
  let(:exchange_rate) { exchange_rate_rates_list.exchange_rates.first }

  let :expected do
    {
      data: {
        id: exchange_rate_rates_list.id,
        type: :exchange_rates_list,
        attributes: {
          year: exchange_rate_rates_list.year,
          month: exchange_rate_rates_list.month,
          publication_date: exchange_rate_rates_list.publication_date,
        },
        relationships: {
          exchange_rate_files: {
            data: [
              {
                id: exchange_rate_file.id,
                type: :exchange_rate_file,
              },
            ],
          },
          exchange_rates: {
            data: [
              {
                id: exchange_rate.id,
                type: :exchange_rate,
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
