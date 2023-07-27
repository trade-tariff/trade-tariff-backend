RSpec.describe ExchangeRates::UploadMonthlyFileService do
  subject(:upload_file) { described_class.call(type) }

  let(:current_time) { Time.zone.now }
  let(:month) { current_time.month }
  let(:year) { current_time.year }
  let(:data_result) { [instance_double('ExchangeRateCurrencyRate')] }

  before do
    travel_to Time.zone.local(2023, 7, 20)

    allow(::ExchangeRateCurrencyRate).to receive(:for_month).with(month, year).and_return(data_result)
    allow(ExchangeRates::CreateCsvService).to receive(:call).with(data_result).and_return('csv_string')
    allow(ExchangeRates::CreateXmlService).to receive(:call).with(data_result).and_return('xml_string')
    allow(TariffSynchronizer::FileService).to receive(:write_file).and_return(true)
    allow(Rails.logger).to receive(:info).and_return(true)
  end

  after do
    travel_back
  end

  context 'when type is :csv' do
    let(:type) { :csv }

    it 'uploads the CSV file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsvService).to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateXmlService).not_to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file)
      expect(Rails.logger).to have_received(:info)
    end
  end

  context 'when type is :xml' do
    let(:type) { :xml }

    it 'uploads the XML file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsvService).not_to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateXmlService).to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file)
      expect(Rails.logger).to have_received(:info)
    end
  end

  context 'when type is invalid' do
    let(:type) { :invalid_type }

    it 'raises ArgumentError' do
      expect { upload_file }.to raise_error(ArgumentError, 'Invalid type: invalid_type. Type must be :csv or :xml.')
    end
  end

  context 'when it is not the penultimate Thursday' do
    before do
      travel_to Time.zone.local(2023, 7, 6)
    end

    let(:type) { :csv }

    it 'does not upload the file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).not_to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsvService).not_to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateXmlService).not_to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).not_to have_received(:write_file)
      expect(Rails.logger).not_to have_received(:info)
    end
  end
end
