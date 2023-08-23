RSpec.describe ExchangeRates::UploadMonthlyFileService do
  subject(:upload_file) { described_class.call(type) }

  let(:current_time) { Time.zone.now }
  let(:month) { current_time.next_month.month }
  let(:year) { current_time.year }
  let(:data_result) { [instance_double('ExchangeRateCurrencyRate')] }

  before do
    travel_to Time.zone.local(2023, 7, 20)

    allow(::ExchangeRateCurrencyRate).to receive(:for_month).with(month, year).and_return(data_result)
    allow(ExchangeRates::CreateCsvService).to receive(:call).with(data_result).and_return('csv_string')
    allow(ExchangeRates::CreateXmlService).to receive(:call).with(data_result).and_return('xml_string')
    allow(ExchangeRates::CreateCsvHmrcService).to receive(:call).with(data_result).and_return('csv_hmrc_string')
    allow(TariffSynchronizer::FileService).to receive(:write_file).and_return(true)
    allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(321)
    allow(ExchangeRateFile).to receive(:create).and_return(true)
    allow(Rails.logger).to receive(:info).and_return(true)
  end

  after do
    travel_back
  end

  context 'when type is :monthly_csv' do
    let(:type) { :monthly_csv }

    it 'uploads the CSV file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsvService).to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateXmlService).not_to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).with("data/exchange_rates/#{year}/#{month}/monthly_csv_#{year}-#{month}.csv", 'csv_string')
      expect(TariffSynchronizer::FileService).to have_received(:file_size).with("data/exchange_rates/#{year}/#{month}/monthly_csv_#{year}-#{month}.csv")
      expect(ExchangeRateFile).to have_received(:create).with(
        period_year: year,
        period_month: month,
        format: :csv,
        type: :monthly_csv,
        file_size: 321,
        publication_date: current_time,
      )
      expect(Rails.logger).to have_received(:info)
    end
  end

  context 'when type is :monthly_xml' do
    let(:type) { :monthly_xml }

    it 'uploads the XML file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsvService).not_to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateXmlService).to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).with("data/exchange_rates/#{year}/#{month}/monthly_xml_#{year}-#{month}.xml", 'xml_string')
      expect(TariffSynchronizer::FileService).to have_received(:file_size).with("data/exchange_rates/#{year}/#{month}/monthly_xml_#{year}-#{month}.xml")
      expect(ExchangeRateFile).to have_received(:create).with(
        period_year: year,
        period_month: month,
        format: :xml,
        type: :monthly_xml,
        file_size: 321,
        publication_date: current_time,
      )
      expect(Rails.logger).to have_received(:info)
    end
  end

  context 'when type is :monthly_csv_hmrc' do
    let(:type) { :monthly_csv_hmrc }

    it 'uploads the CSV file', :aggregate_failures do
      upload_file

      expect(::ExchangeRateCurrencyRate).to have_received(:for_month).with(month, year)
      expect(ExchangeRates::CreateCsvHmrcService).to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateCsvService).not_to have_received(:call).with(data_result)
      expect(ExchangeRates::CreateXmlService).not_to have_received(:call).with(data_result)
      expect(TariffSynchronizer::FileService).to have_received(:write_file).with("data/exchange_rates/#{year}/#{month}/monthly_csv_hmrc_#{year}-#{month}.csv", 'csv_hmrc_string')
      expect(TariffSynchronizer::FileService).to have_received(:file_size).with("data/exchange_rates/#{year}/#{month}/monthly_csv_hmrc_#{year}-#{month}.csv")
      expect(ExchangeRateFile).to have_received(:create).with(
        period_year: year,
        period_month: month,
        format: :csv,
        type: :monthly_csv_hmrc,
        file_size: 321,
        publication_date: current_time,
      )
      expect(Rails.logger).to have_received(:info)
    end
  end

  context 'when type is invalid' do
    let(:type) { :invalid_type }

    it 'raises ArgumentError' do
      expect { upload_file }.to raise_error(ArgumentError, 'Invalid type: invalid_type.')
    end
  end

  context 'when data doesnt exist in the database' do
    let(:data_result) { [] }
    let(:type) { :monthly_xml }

    it 'raises ArgumentError' do
      expect { upload_file }.to raise_error(ExchangeRates::DataNotFoundError, "No exchange rate data found for month #{month} and year #{year}.")
    end
  end
end
