RSpec.describe ExchangeRates::UploadMonthlyCsv do
  subject(:upload_csv) { described_class.call }

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:current_time) { Time.zone.now }
  let(:month) { current_time.month }
  let(:year) { current_time.year }
  let(:data_result) { [instance_double('ExchangeRateCurrecyRate')] }
  let(:date_string) { current_time.to_date.to_s }
  let(:csv_string) { 'csv_string' }
  let(:file_path) { "data/exchange_rates/monthly_csv_#{date_string}.csv" }
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  context 'when its a penultimate thursday' do
    before do
      Timecop.freeze(Time.zone.local(2023, 7, 20))
      allow(::ExchangeRateCurrencyRate).to receive(:for_month).with(month, year).and_return(data_result)
      allow(ExchangeRates::CreateCsv).to receive(:call).with(data_result).and_return(csv_string)
      allow(TariffSynchronizer::FileService).to receive(:write_file).with(file_path, csv_string).and_return(true)
      allow(ActiveSupport::Notifications)
        .to receive(:instrument)
        .with('exchange_rates.monthly_csv',
              date: date_string,
              path: "data/exchange_rates/monthly_csv_#{date_string}.csv",
              size: csv_string.size)
        .and_return(true)
    end

    it 'uploads the csv', :aggregate_failures do
      upload_csv

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsv).to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).with(file_path, csv_string)
      expect(ActiveSupport::Notifications)
        .to have_received(:instrument)
        .with('exchange_rates.monthly_csv',
              date: date_string,
              path: "data/exchange_rates/monthly_csv_#{date_string}.csv",
              size: csv_string.size)
    end
  end

  context 'when its not a penultimate thursday' do
    before do
      Timecop.freeze(Time.zone.local(2023, 7, 0o6))
      allow(::ExchangeRateCurrencyRate).to receive(:for_month).with(month, year).and_return(data_result)
      allow(ExchangeRates::CreateCsv).to receive(:call).with(data_result).and_return(csv_string)
      allow(TariffSynchronizer::FileService).to receive(:write_file).with(file_path, csv_string).and_return(true)
      allow(ActiveSupport::Notifications)
        .to receive(:instrument)
        .with('exchange_rates.monthly_csv',
              date: date_string,
              path: "data/exchange_rates/monthly_csv_#{date_string}.csv",
              size: csv_string.size)
        .and_return(true)
    end

    it 'does not upload the csv', :aggregate_failures do
      upload_csv

      expect(::ExchangeRateCurrencyRate).not_to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsv).not_to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).not_to have_received(:write_file).with(file_path, csv_string)
      expect(ActiveSupport::Notifications)
        .not_to have_received(:instrument)
        .with('exchange_rates.monthly_csv',
              date: date_string,
              path: "data/exchange_rates/monthly_csv_#{date_string}.csv",
              size: csv_string.size)
    end
  end
end
