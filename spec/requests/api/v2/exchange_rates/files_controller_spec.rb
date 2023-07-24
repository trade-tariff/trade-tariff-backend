RSpec.describe Api::V2::ExchangeRates::FilesController, type: :request do
  describe 'GET #index' do
    let(:csv_data) { 'foo,bar\nqux,qul' }
    let(:xml_data) { '<xml><data>...</data></xml>' }
    let(:year) { 2023 }
    let(:month) { 7 }

    before do
      allow(TariffSynchronizer::FileService).to receive(:get).and_call_original
      allow(TariffSynchronizer::FileService).to receive(:get).with("data/exchange_rates/monthly_csv_#{year}-#{month}.csv").and_return(StringIO.new(csv_data))
      allow(TariffSynchronizer::FileService).to receive(:get).with("data/exchange_rates/monthly_xml_#{year}-#{month}.xml").and_return(StringIO.new(xml_data))
    end

    context 'when requesting CSV format' do
      before { get api_exchange_rates_files_path(format: :csv, year:, month:) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type text/csv; charset=utf-8' do
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=#{TradeTariffBackend.service}-monthly_csv_#{year}-#{month}.csv")
      end

      it 'returns the CSV data as the response body' do
        expect(response.body).to eq(csv_data)
      end
    end

    context 'when requesting XML format' do
      before { get api_exchange_rates_files_path(format: :xml, year:, month:) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type application/xml; charset=utf-8' do
        expect(response.content_type).to eq('application/xml; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=#{TradeTariffBackend.service}-monthly_xml_#{year}-#{month}.xml")
      end

      it 'returns the XML data as the response body' do
        expect(response.body).to eq(xml_data)
      end
    end
  end
end
