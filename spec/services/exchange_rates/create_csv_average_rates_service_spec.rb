RSpec.describe ExchangeRates::CreateCsvAverageRatesService do
  subject(:create_csv) { described_class.call(data) }

  let(:data) do
    {
      create(:exchange_rate_country_currency, :eu) => 1.2434658,
      create(:exchange_rate_country_currency, :us) => 1.453546,
      create(:exchange_rate_country_currency, :kz) => 453.46583,
      create(:exchange_rate_country_currency, :kz, currency_description: 'Dollar', currency_code: 'USD') => 1.453546,
    }
  end

  let(:parsed_csv) do
    <<~CSV
      Country,Unit Of Currency,Currency Code,Sterling value of Currency Unit £,Currency Units per £1
      Eurozone,Euro,EUR,0.8042,1.2435
      United States,Dollar,USD,0.6880,1.4535
      Kazakhstan,Tenge,KZT,0.0022,453.4658
      Kazakhstan,Dollar,USD,0.6880,1.4535
    CSV
  end

  it { expect(create_csv).to eq(parsed_csv) }
end
