RSpec.describe 'Stored search analytics read model', :truncation do
  let(:now) { Time.utc(2026, 9, 16, 12) }
  let(:date) { now.to_date - 1 }
  let(:region) { ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')) }
  let(:key) { Digest::SHA256.hexdigest('frontend-journey') }

  around { |example| travel_to(now) { example.run } }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    definitions = SearchAnalytics::DailyQuery.new(reporting_date: date, region:).fingerprints
    groups = definitions.keys.index_with { [] }
    groups['search_journeys'] = [{ '@timestamp' => '2026-09-15T08:00:00Z', 'search_type' => 'classic', 'request_source' => 'frontend', 'journey_keys' => [key] }]
    groups['volume'] = [{ '@timestamp' => '2026-09-15T08:00:00Z', 'search_type' => 'classic', 'event' => 'search_completed', 'searches' => '1', 'zero_results' => '0' }]
    groups['journey_outcomes'] = [{ 'journey_keys' => [key], 'terminal_state' => 'completed', 'window_end' => '2026-09-15T09:00:00Z', 'selected' => '1', 'zero_result' => '0', 'questions_seen' => '0', 'unknown_seen' => '0' }]
    groups.each do |name, rows|
      SearchAnalyticsQueryResult.create(service: 'uk', reporting_date: date, name:, fingerprint: definitions.fetch(name), rows: Sequel.pg_jsonb(rows), collected_at: now)
    end
    SearchAnalytics::ReadModelRefresh.call(region:, from: date, to: date, now:)
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('No collection on page reads')
  end

  it 'serves the existing API contract from the current generation' do
    expect(SearchAnalytics::DailyResults).not_to receive(:legacy_call)
    expect(SearchAnalytics::ReadModelRefresh).not_to receive(:call)
    get '/uk/admin/search_analytics.json', params: { period: '24h', view: 'all' }, headers: request_headers(format: :json)
    expect(response).to have_http_status(:ok)
    attributes = JSON.parse(response.body).fetch('data').fetch('attributes')
    expect(attributes.fetch('summary')).to include('searches' => 1)
    expect(attributes.dig('journeys', 'outcomes')).to include('completed' => 1, 'selected' => 1)
    expect(attributes.fetch('coverage')).to include('complete' => true, 'collected_days' => 1)
  end

  it 'serves fresh source data rather than a stale generation after replacement' do
    row = SearchAnalyticsQueryResult.where(name: 'search_journeys').first
    rows = row.rows.to_a.deep_dup
    rows.first['journey_keys'] << Digest::SHA256.hexdigest('new-journey')
    row.update(rows: Sequel.pg_jsonb(rows), collected_at: now + 1)
    expect(SearchAnalytics::ReadModelProjection).not_to receive(:new)
    get '/uk/admin/search_analytics.json', params: { period: '24h', view: 'all' }, headers: request_headers(format: :json)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig('data', 'attributes', 'summary', 'searches')).to eq(2)
  end

  it 'retains date validation before accessing the read model' do
    expect(SearchAnalytics::ReadModelProjection).not_to receive(:new)
    get '/uk/admin/search_analytics.json', params: { period: 'custom', from: 'bad', to: date.iso8601 }, headers: request_headers(format: :json)
    expect(response).to have_http_status(:bad_request)
  end
end
