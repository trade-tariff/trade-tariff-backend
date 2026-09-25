RSpec.describe Api::Admin::SearchExport::WorkbooksController do
  include_context 'with workbook exports'

  let(:today) { Time.utc(2026, 9, 24, 9) }
  let(:path) { "/#{TradeTariffBackend.service}/admin/search_export/workbooks" }

  before do
    allow(SearchExport::WorkbookWorker).to receive(:perform_async).and_return('job-id')
    allow(SearchExport::CloudwatchReader).to receive(:call).and_return(SearchExport::CloudwatchReader::Result.new(journeys: [], clicks: {}))
  end

  def submit
    post "#{path}.json", params: { from: '2026-09-23', to: '2026-09-24' }, headers: request_headers, as: :json
  end

  it 'queues dates without running CloudWatch in the request' do
    travel_to(today) do
      submit
      expect(response).to have_http_status(:accepted)
      expect(SearchExport::WorkbookWorker).to have_received(:perform_async)
      expect(SearchExport::CloudwatchReader).not_to have_received(:call)
      expect(response.parsed_body.dig('data', 'attributes', 'status')).to eq('queued')
    end
  end

  it 'builds the workbook asynchronously and serves its temporary bytes' do
    travel_to(today) do
      submit
      id = response.parsed_body.dig('data', 'id')
      SearchExport::WorkbookWorker.new.perform(id)
      get "#{path}/#{id}.json", headers: request_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'attributes')).to include('status' => 'ready', 'row_count' => 0, 'omitted_count' => 0)
      get "#{path}/#{id}/download", headers: request_headers
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(response.headers['Content-Disposition']).to include('classifier-workbook-2026-09-23-2026-09-24.xlsx')
      expect(response.body.b).to eq(SearchExport::WorkbookExport.find(id).file.b)
    end
  end

  it 'does not read workbook bytes during polling' do
    export = SearchExport::WorkbookExport.create(from_date: Date.yesterday, to_date: Date.current)
    allow(SearchExport::WorkbookExport).to receive(:find).with(export.id).and_return(export)
    allow(export).to receive(:file)
    get "#{path}/#{export.id}.json", headers: request_headers
    expect(response).to have_http_status(:ok)
    expect(export).not_to have_received(:file)
  end

  it 'keeps a pending export available after fifteen minutes' do
    export = SearchExport::WorkbookExport.create(from_date: Date.yesterday, to_date: Date.current)
    travel 16.minutes do
      get "#{path}/#{export.id}.json", headers: request_headers
      expect(response.parsed_body.dig('data', 'attributes', 'status')).to eq('queued')
    end
  end

  it 'returns not found for an unknown export' do
    get "#{path}/0.json", headers: request_headers
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects an invalid date range' do
    travel_to(today) do
      post "#{path}.json", params: { from: '2026-09-24', to: '2026-09-23' }, headers: request_headers, as: :json
      expect(response).to have_http_status(:bad_request)
      expect(SearchExport::WorkbookWorker).not_to have_received(:perform_async)
    end
  end

  it 'reports rejected enqueueing and removes the orphan status' do
    allow(SearchExport::WorkbookWorker).to receive(:perform_async).and_return(nil)
    travel_to(today) { submit }
    expect(response).to have_http_status(:service_unavailable)
    expect(workbook_exports.last.payload).to be_nil
  end

  it 'returns service unavailable when Redis is unavailable' do
    allow(SearchExport::WorkbookExport).to receive(:create).and_raise(RedisClient::CannotConnectError)
    travel_to(today) { submit }
    expect(response).to have_http_status(:service_unavailable)
  end

  ['', '/download'].each do |suffix|
    it "handles Redis failures while loading an export#{suffix}" do
      allow(SearchExport::WorkbookExport).to receive(:find).and_raise(RedisClient::CannotConnectError)
      get "#{path}/unknown#{suffix}", headers: request_headers
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  it 'returns not found for an unknown download' do
    get "#{path}/unknown/download", headers: request_headers
    expect(response).to have_http_status(:not_found)
  end

  it 'queues another export when three exports already exist' do
    3.times { SearchExport::WorkbookExport.create(from_date: Date.yesterday, to_date: Date.current) }
    travel_to(today) { submit }
    expect(response).to have_http_status(:accepted)
    expect(SearchExport::WorkbookWorker).to have_received(:perform_async)
  end

  it 'accepts date ranges longer than a year' do
    travel_to(today) do
      post "#{path}.json", params: { from: '2025-01-01', to: '2026-09-24' }, headers: request_headers, as: :json
      expect(response).to have_http_status(:accepted)
      expect(SearchExport::WorkbookWorker).to have_received(:perform_async)
    end
  end
end
