RSpec.describe Api::Admin::SearchAnalyticsController do
  let(:date) { Time.current.utc.to_date - 1 }
  let(:region) { ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')) }

  before do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('API reads must not construct an AWS client')
    allow(SearchAnalyticsQueryWorker).to receive(:enqueue_day).and_raise('API reads must not enqueue collection')
    create_results(date)
  end

  def create_results(day)
    collector = SearchAnalytics::DailyQuery.new(reporting_date: day, region:)
    bucket = (day.to_time(:utc) + 8.hours).iso8601
    rows = collector.query_definitions.keys.index_with { [] }
    rows['volume'] = [{ '@timestamp' => bucket, 'search_type' => 'interactive', 'event' => 'search_completed', 'searches' => 3, 'zero_results' => 0 }]
    rows['search_journeys'] = [
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'frontend', 'journey_keys' => %w[same-journey] },
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'admin', 'journey_keys' => %w[admin] },
    ]
    rows['ai_cost_summary'] = [{ 'journey_key' => 'same-journey', 'total_cost_usd' => '0.03', 'priced_calls' => 2, 'unpriced_calls' => 1 }]
    rows['ai_cost_trend'] = [{ '@timestamp' => bucket, 'journey_key' => 'same-journey', 'event_kind' => 'interactive_search', 'total_cost_usd' => '0.03', 'calls' => 3, 'priced_calls' => 2, 'unpriced_calls' => 1 }]
    fingerprints = collector.fingerprints
    rows.each do |name, values|
      SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: day, name:, fingerprint: fingerprints.fetch(name), rows: Sequel.pg_jsonb(values), collected_at: Time.current)
    end
  end

  def request_analytics(params = {})
    get "/#{TradeTariffBackend.service}/admin/search_analytics.json", params:, headers: request_headers(format: :json)
  end

  def attributes = response.parsed_body.dig('data', 'attributes')

  it 'serves the stored daily contract with journey count, costs and coverage' do
    request_analytics(period: '24h', view: 'internal')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'id')).to eq("#{TradeTariffBackend.service}-24h-internal")
    expect(attributes['summary']).to include('searches' => 1, 'requests' => 3)
    expect(attributes.dig('ai_costs', 'summary')).to include('total_cost_usd' => 0.03, 'priced_calls' => 2, 'unpriced_calls' => 1, 'complete' => false)
    expect(attributes.dig('ai_costs', 'operations').first['calls']).to eq(3)
    expect(attributes['coverage']).to include('from' => date.iso8601, 'to' => date.iso8601, 'complete' => true, 'collected_days' => 1)
    expect(attributes['availability']).to include('journey_metrics' => true, 'costs_match_view' => true)
    expect(attributes['bucket_size']).to eq('hour')
  end

  it 'deduplicates journeys across collected days while adding every call and cost' do
    create_results(date - 1)
    request_analytics(period: '7d', view: 'internal')

    expect(response).to have_http_status(:ok)
    expect(attributes.dig('summary', 'searches')).to eq(1)
    expect(attributes.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(0.06)
    expect(attributes.dig('ai_costs', 'operations').first['calls']).to eq(6)
    expect(attributes['coverage']).to include('collected_days' => 2, 'expected_days' => 7, 'complete' => false)
    expect(attributes['bucket_size']).to eq('day')
  end

  it 'does not perform writes or collection during a page read' do
    expect { request_analytics }.not_to change(SearchAnalyticsQueryResult, :count)
    expect(response).to have_http_status(:ok)
    expect(SearchAnalyticsQueryWorker).not_to have_received(:enqueue_day)
    expect(Aws::CloudWatchLogs::Client).not_to have_received(:new)
  end

  it 'connects daily scheduling through per-query jobs to a read-only API response' do
    SearchAnalyticsQueryResult.dataset.delete
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_call_original
    client = Aws::CloudWatchLogs::Client.new(region:, stub_responses: true)
    client.stub_responses(:start_query, query_id: 'offline-query')
    client.stub_responses(:get_query_results, status: 'Complete', results: [], statistics: { records_matched: 0.0 })
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalyticsQueryWorker).to receive(:enqueue_day).and_call_original
    Sidekiq::Testing.fake! do
      SearchAnalyticsQueryWorker.clear
      SearchAnalyticsSnapshotWorker.new.perform
      expect(SearchAnalyticsQueryWorker.jobs.size).to eq(9)
      SearchAnalyticsQueryWorker.drain
    end
    request_analytics
    expect(response).to have_http_status(:ok)
    expect(attributes['coverage']).to include('complete' => true, 'collected_days' => 1)
    expect(SearchAnalyticsQueryResult.count).to eq(9)
  end

  it 'normalises unknown period and view values' do
    request_analytics(period: 'bad', view: 'bad')
    expect(response.parsed_body.dig('data', 'id')).to eq("#{TradeTariffBackend.service}-24h-all")
  end

  it 'returns not found for an incomplete day without falling back to rolling snapshots' do
    create(:search_analytics_snapshot)
    SearchAnalyticsQueryResult.where(name: 'search_journeys').delete
    request_analytics
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig('errors', 0, 'title')).to eq('Search analytics unavailable')
  end

  it 'rejects stale query definitions instead of returning inconsistent data' do
    SearchAnalyticsQueryResult.where(name: 'ai_cost_trend').update(fingerprint: 'obsolete')
    request_analytics
    expect(response).to have_http_status(:not_found)
  end

  it 'uses inclusive custom dates and includes the bounds in the resource ID' do
    create_results(date - 1)
    request_analytics(period: 'custom', view: 'internal', from: (date - 1).iso8601, to: date.iso8601)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'id')).to eq("#{TradeTariffBackend.service}-custom-internal-#{date - 1}-#{date}")
    expect(attributes['coverage']).to include('complete' => true, 'expected_days' => 2)
    expect(attributes['period']).to eq('custom')
  end

  it 'keeps hourly detail for a single custom day' do
    request_analytics(from: date.iso8601, to: date.iso8601)
    expect(response).to have_http_status(:ok)
    expect(attributes['bucket_size']).to eq('hour')
  end

  it 'rejects missing, invalid, future and oversized custom date ranges' do
    [
      { period: 'custom' },
      { from: date.iso8601 },
      { from: 'invalid', to: date.iso8601 },
      { from: date.iso8601, to: (date - 1).iso8601 },
      { from: date.iso8601, to: (date + 1).iso8601 },
      { from: (date - 366).iso8601, to: date.iso8601 },
    ].each do |params|
      request_analytics(params)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig('errors', 0, 'title')).to eq('Invalid date range')
    end
  end
end
