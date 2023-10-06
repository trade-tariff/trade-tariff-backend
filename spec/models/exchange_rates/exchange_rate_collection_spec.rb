RSpec.describe ExchangeRates::ExchangeRateCollection do
  let(:year) { 2023 }
  let(:month) { 6 }
  let(:publication_date) { '2023-06-22T00:00:00.000Z' }

  describe '#id' do
    subject(:rates_list) { build(:exchange_rates_collection, :with_rates_file) }

    it { expect(rates_list.id).to be_present }
  end

  describe '#exchange_rate_file_ids' do
    subject(:rates_list) { build(:exchange_rates_collection, :with_rates_file) }

    it { expect(rates_list.exchange_rate_file_ids).to all(be_present) }
  end

  describe '#exchange_rate_ids' do
    subject(:rates_list) { build(:exchange_rates_collection, :with_rates_file) }

    it 'returns the ids of exchange rate periods' do
      expect(rates_list.exchange_rate_ids).to be_empty
    end
  end

  describe '.build' do
    subject(:rates_list) { build(:exchange_rates_collection, :with_rates_file, year:, month:) }

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
    subject(:exchange_rates) { described_class.exchange_rates('1', '2020', ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE) }

    before do
      create(
        :exchange_rate_country_currency,
        currency_code: 'EUR',
        country_code: 'DE',
        country_description: 'Germany',
        currency_description: 'Euro',
        validity_start_date: '2020-01-01',
        validity_end_date: '2020-01-31',
      )
      create(
        :exchange_rate_country_currency,
        currency_code: 'EUR',
        country_code: 'DE',
        country_description: 'Deutschland',
        currency_description: 'Euro',
        validity_start_date: '2020-01-02',
        validity_end_date: '2020-01-31',
      )
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        currency_code: 'EUR',
        validity_start_date: '2020-01-01',
        validity_end_date: '2020-01-31',
      )

      create(
        :exchange_rate_country_currency,
        currency_code: 'USD',
        country_code: 'US',
        country_description: 'United States',
        validity_start_date: '2020-01-01',
        validity_end_date: '2020-01-31',
      )
      create(
        :exchange_rate_currency_rate,
        :scheduled_rate,
        currency_code: 'USD',
        validity_start_date: '2020-01-01',
        validity_end_date: '2020-01-31',
      )
    end

    it { expect(exchange_rates.pluck(:country_description)).to eq(['Deutschland', 'United States']) }
  end
end
