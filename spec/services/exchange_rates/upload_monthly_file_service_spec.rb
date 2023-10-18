RSpec.describe ExchangeRates::UploadMonthlyFileService do
  subject(:call) { described_class.new(rates, date, type).call }

  let(:rates) { create_list(:exchange_rate_currency_rate, 1, :with_usa) }
  let(:date) { Time.zone.today }

  before do
    allow(TariffSynchronizer::FileService).to receive(:write_file)
    allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(1)
    allow(ExchangeRates::CreateCsvService).to receive(:new).and_call_original
    allow(ExchangeRates::CreateXmlService).to receive(:new).and_call_original
    allow(ExchangeRates::CreateCsvHmrcService).to receive(:new).and_call_original

    call
  end

  context 'when type is :monthly_csv' do
    let(:type) { :monthly_csv }

    it { expect(TariffSynchronizer::FileService).to have_received(:write_file).with(match(/monthly_csv_\d{4}-\d{2}.csv/), include('Country')) }
    it { expect(ExchangeRateFile.count).to eq(1) }
    it { expect(ExchangeRates::CreateCsvService).to have_received(:new).with(rates) }
  end

  context 'when type is :monthly_xml' do
    let(:type) { :monthly_xml }

    it { expect(TariffSynchronizer::FileService).to have_received(:write_file).with(match(/monthly_xml_\d{4}-\d{2}.xml/), include('countryName')) }
    it { expect(ExchangeRateFile.count).to eq(1) }
    it { expect(ExchangeRates::CreateXmlService).to have_received(:new).with(rates) }
  end

  context 'when type is :monthly_csv_hmrc' do
    let(:type) { :monthly_csv_hmrc }

    it { expect(TariffSynchronizer::FileService).to have_received(:write_file).with(match(/monthly_csv_hmrc_\d{4}-\d{2}.csv/), include('Period')) }
    it { expect(ExchangeRateFile.count).to eq(1) }
    it { expect(ExchangeRates::CreateCsvHmrcService).to have_received(:new).with(rates) }
  end

  context 'when type is :spot_csv' do
    let(:type) { :spot_csv }
    let(:rates) { create_list(:exchange_rate_currency_rate, 1, :spot_rate, :with_usa) }

    it 'uploads the CSV file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(7, year, 'spot')
      expect(ExchangeRates::CreateCsvService).to have_received(:call).with(rates)
      expect(ExchangeRates::CreateXmlService).not_to have_received(:call).with(rates)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).with("data/exchange_rates/#{year}/#{month}/spot_csv_#{year}-#{month}.csv", 'csv_string')
      expect(TariffSynchronizer::FileService).to have_received(:file_size).with("data/exchange_rates/#{year}/#{month}/spot_csv_#{year}-#{month}.csv")
      expect(ExchangeRateFile).to have_received(:create).with(
        period_year: year,
        period_month: month,
        format: :csv,
        type: :spot_csv,
        file_size: 321,
        publication_date: current_time,
      )
    end
  end
end
