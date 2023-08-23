RSpec.describe ExchangeRates::RatesList do
  let(:year) { 2023 }
  let(:month) { 6 }
  let(:publication_date) { '2023-06-22T00:00:00.000Z' }

  describe '#id' do
    subject(:rates_list) { build(:exchange_rates_list, :with_rates_file) }

    it 'returns the correct id' do
      expect(rates_list.id).to eq("#{year}-#{month}-exchange_rate_period")
    end
  end

  describe '#exchange_rate_file_ids' do
    subject(:rates_list) { build(:exchange_rates_list, :with_rates_file) }

    it 'returns the ids of exchange rate years' do
      expect(rates_list.exchange_rate_file_ids).to eq(['2023-6-csv_file'])
    end
  end

  describe '#exchange_rate_ids' do
    subject(:rates_list) { build(:exchange_rates_list, :with_rates_file) }

    it 'returns the ids of exchange rate periods' do
      expect(rates_list.exchange_rate_ids).to be_empty
    end
  end

  describe '.build' do
    subject(:rates_list) { build(:exchange_rates_list, :with_rates_file, year:, month:) }

    it 'builds a rates list with exchange rates and exchange rate files' do
      expect(rates_list).to be_an_instance_of(described_class)
    end

    it 'sets the year correctly' do
      expect(rates_list.year).to eq(year)
    end

    it 'sets the month correctly' do
      expect(rates_list.month).to eq(month)
    end

    it 'sets the publication_date correctly' do
      expect(rates_list.publication_date).to eq(publication_date)
    end

    it 'initializes exchange rate files to include an instance of a file' do
      expect(rates_list.exchange_rate_files.first).to be_an_instance_of(ExchangeRateFile)
    end

    it 'initializes exchange rates to an empty array' do
      expect(rates_list.exchange_rates).to be_empty
    end
  end

  describe '.exchange_rates' do
    subject(:exchange_rates) { described_class.exchange_rates(month, year) }

    let(:rates) { build_list(:exchange_rate_currency_rate, 1) }

    before do
      allow(ExchangeRateCurrencyRate)
        .to receive(:by_month_and_year)
        .with(month, year)
        .and_call_original
    end

    it 'calls ExchangeRateCurrencyRate.build with the correct arguments' do
      allow(Api::V2::ExchangeRates::CurrencyRatePresenter)
        .to receive(:wrap)
        .with(anything, month, year)
        .and_return([])

      exchange_rates
    end

    it 'returns an array' do
      expect(exchange_rates).to be_an(Array)
    end

    it 'returns an array of ExchangeRateCurrencyRate instances' do
      expect(exchange_rates).to all(be_an_instance_of(ExchangeRateCurrencyRate))
    end
  end
end
