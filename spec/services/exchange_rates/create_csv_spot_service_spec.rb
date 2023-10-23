RSpec.describe ExchangeRates::CreateCsvSpotService do
    subject(:create_csv) { described_class.call(data) }
  
    let(:data) { ExchangeRateCurrencyRate.for_month(2, 2020, 'spot') }
    let(:parsed_csv) do
      "Country,Unit Of Currency,Currency Code,Sterling value of Currency Unit £,Currency Units per £1\nUnited States,Dollar,USD,0.20828126301757896,4.8012\n"
    end
  
    before do
      create(
        :exchange_rate_currency_rate,
        :with_usa,
        :spot_rate,
        validity_start_date: '2020-02-01',
      )
    end
  
    it { expect(create_csv).to eq(parsed_csv) }
  end
  