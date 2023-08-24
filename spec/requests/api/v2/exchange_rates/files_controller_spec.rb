RSpec.describe Api::V2::ExchangeRates::FilesController, type: :request do
  describe 'GET #index' do
    let(:year) { 2023 }
    let(:month) { 7 }
    let(:data) { 'foo,bar\nqux,qul' }

    before do
      allow(TariffSynchronizer::FileService).to receive(:get).and_call_original
      allow(TariffSynchronizer::FileService).to receive(:get).with("data/exchange_rates/#{year}/#{month}/#{type}_#{year}-#{month}.#{format}").and_return(StringIO.new(data))
    end

    context 'when requesting CSV format' do
      let(:type) { 'monthly_csv' }
      let(:format) { 'csv' }

      before { get api_exchange_rates_file_path("#{type}_#{year}-#{month}", format: :csv) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type text/csv; charset=utf-8' do
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=monthly_csv_#{year}-#{month}.csv")
      end

      it 'returns the CSV data as the response body' do
        expect(response.body).to eq(data)
      end
    end

    context 'when requesting XML format' do
      let(:type) { 'monthly_xml' }
      let(:format) { 'xml' }

      before { get api_exchange_rates_file_path("#{type}_#{year}-#{month}", format: :xml) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type application/xml; charset=utf-8' do
        expect(response.content_type).to eq('application/xml; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=monthly_xml_#{year}-#{month}.xml")
      end

      it 'returns the XML data as the response body' do
        expect(response.body).to eq(data)
      end
    end
  end
end
