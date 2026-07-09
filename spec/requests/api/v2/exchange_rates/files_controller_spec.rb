RSpec.describe Api::V2::ExchangeRates::FilesController, :v2 do
  describe 'GET #index' do
    let(:year) { 2023 }
    let(:month) { 10 }
    let(:data) { 'foo,bar\nqux,qul' }

    before do
      create(:exchange_rate_file, type:, format:, period_year: year, period_month: month)

      allow(TariffSynchronizer::FileService).to receive(:get).and_call_original
      allow(TariffSynchronizer::FileService).to receive(:get).with("data/exchange_rates/#{year}/#{month.to_i}/#{type}_#{year}-#{month.to_i}.#{format}").and_return(StringIO.new(data))
    end

    context 'when requesting CSV format' do
      let(:type) { 'monthly_csv' }
      let(:format) { 'csv' }

      before { api_get api_exchange_rates_file_path("#{type}_#{year}-#{month}", format: :csv) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type text/csv; charset=utf-8' do
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq('attachment; filename=exrates-monthly-1023.csv')
      end

      it 'returns the CSV data as the response body' do
        expect(response.body).to eq(data)
      end

      context 'when the month is prefixed with 0' do
        let(:month) { '07' }

        it 'returns HTTP status :ok' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when requesting XML format' do
      let(:type) { 'monthly_xml' }
      let(:format) { 'xml' }

      before { api_get api_exchange_rates_file_path("#{type}_#{year}-#{month}", format: :xml) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type application/xml; charset=utf-8' do
        expect(response.content_type).to eq('application/xml; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq('attachment; filename=exrates-monthly-1023.xml')
      end

      it 'returns the XML data as the response body' do
        expect(response.body).to eq(data)
      end

      context 'when the month is prefixed with 0' do
        let(:month) { '07' }

        it 'returns HTTP status :ok' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when requesting HMRC CSV format' do
      let(:type) { 'monthly_csv_hmrc' }
      let(:format) { 'csv' }

      before { api_get api_exchange_rates_file_path("#{type}_#{year}-#{month}", format: :csv) }

      it 'returns HTTP status :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type text/csv; charset=utf-8' do
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'returns the correct Content-Disposition header' do
        expect(response.headers['Content-Disposition']).to eq('attachment; filename=202310MonthlyRates.csv')
      end

      it 'returns the CSV data as the response body' do
        expect(response.body).to eq(data)
      end

      context 'when the month is prefixed with 0' do
        let(:month) { '07' }

        it 'returns HTTP status :ok' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when requesting invalid type' do
      let(:type) { 'non_existing_type' }
      let(:format) { 'csv' }

      before { api_get api_exchange_rates_file_path("#{type}_#{year}-#{month}", format: :csv) }

      it 'returns HTTP status :not_found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #index with malformed URL' do
    context 'when requesting malformed URL' do
      it 'returns 404 for missing year-month pattern' do
        api_get api_exchange_rates_file_path('monthly_csv_', format: :csv)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for incomplete pattern' do
        api_get api_exchange_rates_file_path('monthly_csv', format: :csv)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for invalid year format' do
        api_get api_exchange_rates_file_path('monthly_csv_abc-10', format: :csv)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for XML with malformed URL' do
        api_get api_exchange_rates_file_path('monthly_xml_', format: :xml)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
