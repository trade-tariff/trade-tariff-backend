# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe ExchangeRates::UploadMonthlyFileService do
  subject(:upload_file) { described_class.call(type) }

  let(:current_time) { Time.zone.now }
  let(:month) { current_time.month }
  let(:year) { current_time.year }
  let(:data_result) { [instance_double('ExchangeRateCurrecyRate')] }
  let(:date_string) { current_time.to_date.to_s }
  let(:csv_string) { 'csv_string' }
  let(:xml_string) { 'xml_string' }
  let(:csv_file_path) { "data/exchange_rates/monthly_csv_#{year}-#{month}.csv" }
  let(:xml_file_path) { "data/exchange_rates/monthly_xml_#{year}-#{month}.xml" }

  before do
    allow(::ExchangeRateCurrencyRate).to receive(:for_month).with(month, year).and_return(data_result)
    allow(ExchangeRates::CreateCsvService).to receive(:call).with(data_result).and_return(csv_string)
    allow(ExchangeRates::CreateXmlService).to receive(:call).with(data_result).and_return(xml_string)
    allow(TariffSynchronizer::FileService).to receive(:write_file)
    allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
  end

  context 'when its a penultimate thursday' do
    before do
      Timecop.freeze(Time.zone.local(2023, 7, 20))
      allow(Time.zone).to receive(:now).and_return(Time.zone.local(2023, 7, 20))
    end

    context 'with type :csv' do
      let(:type) { :csv }

      it 'uploads CSV data and notifies with the correct details' do
        upload_file

        expect(ExchangeRates::CreateCsvService).to have_received(:call).with(data_result)
        expect(TariffSynchronizer::FileService).to have_received(:write_file).with(csv_file_path, csv_string)
        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          :"exchange_rates.monthly_csv",
          date: date_string,
          path: csv_file_path,
          size: csv_string.size,
        )
      end
    end

    context 'with type :xml' do
      let(:type) { :xml }

      it 'uploads XML data and notifies with the correct details' do
        upload_file

        expect(ExchangeRates::CreateXmlService).to have_received(:call).with(data_result)
        expect(TariffSynchronizer::FileService).to have_received(:write_file).with(xml_file_path, xml_string)
        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          :"exchange_rates.monthly_xml",
          date: date_string,
          path: xml_file_path,
          size: xml_string.size,
        )
      end
    end

    context 'with an invalid type' do
      let(:type) { :invalid_type }

      it 'raises an ArgumentError', :aggregate_failures do
        expect { upload_file }.to raise_error(ArgumentError, "Invalid type: #{type}. Type must be :csv or :xml.")
      end
    end
  end

  context 'when its not a penultimate thursday' do
    before do
      Timecop.freeze(Time.zone.local(2023, 7, 6))
    end

    context 'with type :csv' do
      let(:type) { :csv }

      it 'does not upload the csv or notify' do
        upload_file

        expect(ExchangeRates::CreateCsvService).not_to have_received(:call)
        expect(TariffSynchronizer::FileService).not_to have_received(:write_file)
        expect(ActiveSupport::Notifications).not_to have_received(:instrument)
      end
    end

    context 'with type :xml' do
      let(:type) { :xml }

      it 'does not upload the xml or notify' do
        upload_file

        expect(ExchangeRates::CreateXmlService).not_to have_received(:call)
        expect(TariffSynchronizer::FileService).not_to have_received(:write_file)
        expect(ActiveSupport::Notifications).not_to have_received(:instrument)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
