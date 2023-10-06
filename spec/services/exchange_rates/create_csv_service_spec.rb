RSpec.describe ExchangeRates::CreateCsvService do
  subject(:create_csv) { described_class.call(data) }

  let(:data) { ExchangeRateCurrencyRate.for_month(2, 2020, 'monthly') }
  let(:parsed_csv) do
    "Country/Territories,Currency,Currency Code,Currency Units per £1,Start date,End date\nUnited States,Dollar,USD,4.8012,01/02/2020,29/02/2020\n"
  end

  before do
    create(
      :exchange_rate_currency_rate,
      :with_usa,
      validity_start_date: '2020-02-01',
    )
  end

  it { expect(create_csv).to eq(parsed_csv) }
end
