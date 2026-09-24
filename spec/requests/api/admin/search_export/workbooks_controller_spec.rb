RSpec.describe Api::Admin::SearchExport::WorkbooksController do
  let(:today) { Time.utc(2026, 9, 24, 9) }

  before do
    allow(SearchExport::WorkbookWorker).to receive(:perform_async)
  end

  it 'accepts a range that ends today and enqueues a worker' do
    travel_to(today) do
      post "/#{TradeTariffBackend.service}/admin/search_export/workbooks.json",
           params: { from: '2026-09-23', to: '2026-09-24' },
           headers: request_headers,
           as: :json

      expect(response).to have_http_status(:accepted)
      expect(SearchExport::WorkbookWorker).to have_received(:perform_async)
      expect(response.parsed_body.dig('data', 'attributes', 'status')).to eq('queued')
    end
  end

  it 'builds the queued workbook and serves its stored bytes' do
    travel_to(today) do
      post "/#{TradeTariffBackend.service}/admin/search_export/workbooks.json",
           params: { from: '2026-09-23', to: '2026-09-24' }, headers: request_headers, as: :json

      expect(response).to have_http_status(:accepted)
      id = response.parsed_body.dig('data', 'id')
      SearchExport::WorkbookWorker.new.perform(id)

      get "/#{TradeTariffBackend.service}/admin/search_export/workbooks/#{id}.json", headers: request_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'attributes')).to include('status' => 'ready', 'row_count' => 0, 'omitted_count' => 0)

      get "/#{TradeTariffBackend.service}/admin/search_export/workbooks/#{id}/download", headers: request_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(response.headers['Content-Disposition']).to include('classifier-workbook-2026-09-23-2026-09-24.xlsx')
      expect(response.body.b).to eq(SearchExport::WorkbookExport.with_pk!(id).file)
    end
  end

  it 'rejects a range over the row limit without enqueueing work' do
    allow(SearchExport::Workbook).to receive(:candidate_count).and_return(SearchExport::Workbook::MAX_ROWS + 1)

    travel_to(today) do
      post "/#{TradeTariffBackend.service}/admin/search_export/workbooks.json",
           params: { from: '2026-09-23', to: '2026-09-24' }, headers: request_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(SearchExport::WorkbookWorker).not_to have_received(:perform_async)
      expect(SearchExport::WorkbookExport.count).to eq(0)
    end
  end

  it 'returns not found for an unknown export' do
    get "/#{TradeTariffBackend.service}/admin/search_export/workbooks/0.json", headers: request_headers

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects a range longer than 366 days' do
    travel_to(today) do
      post "/#{TradeTariffBackend.service}/admin/search_export/workbooks.json",
           params: { from: '2025-01-01', to: '2026-09-24' },
           headers: request_headers,
           as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end
end
