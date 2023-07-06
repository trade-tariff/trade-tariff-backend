RSpec.describe ExchangeRates::UploadMonthlyCsv do
  subject(:upload_csv) { described_class.call(date) }

  context 'with valid date' do
    let(:date) { DateTime.new(2023, 2, 1) }
    let(:month) { date.month }
    let(:year) { date.year }
    let(:data_result) { [double('ExchangeRateCurrecyRate')] }
    let(:current_date) { Date.current.to_s }
    let(:csv_string) { 'csv_string' }
    let(:file_path) { "data/exchange_rates/monthly_csv_#{current_date}.csv" }

    before do
      allow(::ExchangeRateCurrencyRate).to receive(:for_month).with(month, year).and_return(data_result)
      allow(ExchangeRates::CreateCsv).to receive(:call).with(data_result).and_return(csv_string)
      allow(TariffSynchronizer::FileService).to receive(:write_file).with(file_path, csv_string).and_return(true)
      allow(ActiveSupport::Notifications)
        .to receive(:instrument)
        .with('exchange_rates.monthly_csv',
              date: current_date,
              path: "data/exchange_rates/monthly_csv_#{current_date}.csv",
              size: csv_string.size)
        .and_return(true)
    end

    it 'uploads the csv' do
      upload_csv

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsv).to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).with(file_path, csv_string)
      expect(ActiveSupport::Notifications)
        .to have_received(:instrument)
        .with('exchange_rates.monthly_csv',
              date: current_date,
              path: "data/exchange_rates/monthly_csv_#{current_date}.csv",
              size: csv_string.size)
    end

  end

end
