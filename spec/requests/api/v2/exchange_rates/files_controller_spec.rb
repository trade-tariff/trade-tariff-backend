RSpec.describe Api::V2::ExchangeRates::FilesController, type: :request do
  describe 'GET #index' do
    let(:year) { 2023 }
    let(:month) { 7 }
    let(:data) { 'foo,bar\nqux,qul' }

    before do
      create(:exchange_rate_file, type: period_type, format:, period_year: year, period_month: month)
      allow(TariffSynchronizer::FileService).to receive(:get).and_call_original
      allow(TariffSynchronizer::FileService).to receive(:get)
        .with("data/exchange_rates/#{year}/#{month}/#{period_type}_#{year}-#{month}.#{format}")
        .and_return(StringIO.new(data))
    end

    context 'when requesting CSV format' do
      let(:period_type) { 'monthly_csv' }
      let(:format) { 'csv' }

      before { get api_exchange_rates_file_path("#{period_type}_#{year}-#{month}", format: :csv) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type text/csv; charset=utf-8' do
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq('attachment; filename=exrates-monthly-0723.csv')
      end

      it 'returns the CSV data as the response body' do
        expect(response.body).to eq(data)
      end
    end

    context 'when requesting XML format' do
      let(:period_type) { 'monthly_xml' }
      let(:format) { 'xml' }

      before { get api_exchange_rates_file_path("#{period_type}_#{year}-#{month}", format: :xml) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type application/xml; charset=utf-8' do
        expect(response.content_type).to eq('application/xml; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq('attachment; filename=exrates-monthly-0723.xml')
      end

      it 'returns the XML data as the response body' do
        expect(response.body).to eq(data)
      end
    end

    context 'when requesting HMRC CSV format' do
      let(:period_type) { 'monthly_csv_hmrc' }
      let(:format) { 'csv' }

      before { get api_exchange_rates_file_path("#{period_type}_#{year}-#{month}", format: :csv) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type text/csv; charset=utf-8' do
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq('attachment; filename=202307MonthlyRates.csv')
      end

      it 'returns the CSV data as the response body' do
        expect(response.body).to eq(data)
      end
    end

    context 'when file not found' do
      let(:period_type) { 'monthly_csv' }
      let(:format) { 'csv' }

      let(:wrong_year) { 2010 }

      before { get api_exchange_rates_file_path("#{period_type}_#{wrong_year}-#{month}", format: :csv) }

      it 'returns HTTP 404  :not_found' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when requesting invalid period type' do
      let(:period_type) { 'invalid_period_type' }
      let(:format) { 'csv' }

      before { get api_exchange_rates_file_path("#{period_type}_#{year}-#{month}", format:) }

      it 'returns HTTP 400 bad request' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
