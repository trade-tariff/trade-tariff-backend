RSpec.describe ExchangeRates::CreateOldFilesService do
  subject(:create_old_files) { described_class.call }

  before do
    setup_data
  end

  describe '.call' do
    let(:month) { 8 }
    let(:year) { '2023' }
    let(:data_result) { double }
    let(:data_string) { double }
    let(:file_size) { double }

    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class)
        .to receive(:old_file_dates)
        .and_return([{ edition_date: 'August 2023', updated_date: '2023-07-20' }])
      # rubocop:enable RSpec/AnyInstance

      allow(::ExchangeRateCurrencyRate).to receive(:for_month).and_return(data_result)
      allow(ExchangeRates::CreateCsvService).to receive(:call).and_return(data_string)
      allow(ExchangeRates::CreateXmlService).to receive(:call).and_return(data_string)
      allow(TariffSynchronizer::FileService).to receive(:write_file)
      allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(file_size)
      allow(ExchangeRateFile).to receive(:create)
      allow(Rails.logger).to receive(:info).and_return(true)
    end

    it 'calls the methods', :aggregate_failures do
      create_old_files

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month)
      expect(ExchangeRates::CreateCsvService).to have_received(:call)
      expect(ExchangeRates::CreateXmlService).to have_received(:call)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).twice
      expect(TariffSynchronizer::FileService).to have_received(:file_size).twice
      expect(ExchangeRateFile).to have_received(:create).twice
      expect(Rails.logger).to have_received(:info).twice
    end
  end

  def setup_data
    all_currency_rates_file = 'spec/fixtures/exchange_rates/all_rates.csv'
    currency_rate_file = 'spec/fixtures/exchange_rates/currency.csv'
    territory_file = 'spec/fixtures/exchange_rates/territory.csv'

    ExchangeRateCurrencyRate.populate(Rails.root.join(all_currency_rates_file))
    ExchangeRateCurrency.populate(Rails.root.join(currency_rate_file))
    ExchangeRateCountry.populate(Rails.root.join(territory_file))
  end
end
