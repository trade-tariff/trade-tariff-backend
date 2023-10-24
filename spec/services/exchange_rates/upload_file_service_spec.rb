RSpec.describe ExchangeRates::UploadFileService do
  subject(:call) { described_class.new(rates, date, type).call }

  let(:rates) { create_list(:exchange_rate_currency_rate, 1, :with_usa) }
  let(:date) { Time.zone.today }

  before do
    allow(TariffSynchronizer::FileService).to receive(:write_file)
    allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(1)
    allow(ExchangeRates::CreateCsvService).to receive(:new).and_call_original
    allow(ExchangeRates::CreateXmlService).to receive(:new).and_call_original
    allow(ExchangeRates::CreateCsvHmrcService).to receive(:new).and_call_original
    allow(ExchangeRates::CreateCsvSpotService).to receive(:new).and_call_original
    allow(ExchangeRates::CreateCsvAverageRatesService).to receive(:new).and_call_original

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

    it { expect(TariffSynchronizer::FileService).to have_received(:write_file).with(match(/spot_csv_\d{4}-\d{2}.csv/), include('Country')) }
    it { expect(ExchangeRateFile.count).to eq(1) }
    it { expect(ExchangeRates::CreateCsvSpotService).to have_received(:new).with(rates) }
  end

  context 'when type is :average_csv' do
    let(:type) { :average_csv }
    let(:rates) do
      {
        create(:exchange_rate_country_currency, :eu) => 1.2434658,
        create(:exchange_rate_country_currency, :us) => 1.453546,
        create(:exchange_rate_country_currency, :kz) => 453.46583,
        create(:exchange_rate_country_currency, :kz, currency_description: 'Dollar', currency_code: 'USD') => 1.453546,
      }
    end

    it 'uploads correctly', :aggregate_failures do
      call

      expect(TariffSynchronizer::FileService).to have_received(:write_file).with(match(/average_csv_\d{4}-\d{2}.csv/), include('Country'))
      expect(ExchangeRateFile.count).to eq(1)
      expect(ExchangeRates::CreateCsvAverageRatesService).to have_received(:new).with(rates)
    end
  end
end
