RSpec.describe 'Search analytics outcome rates API', :truncation do
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
    groups['classic_outcomes'] = [{ 'journey_key' => Digest::SHA256.hexdigest('classic-search'), 'result_count' => '0', 'commodity_result_count' => '2', 'observed_at' => '2026-09-15T08:00:00Z', 'event_count' => '1' }]
    groups.each do |name, rows|
      SearchAnalyticsQueryResult.create(service: 'uk', reporting_date: date, name:, fingerprint: definitions.fetch(name), rows: Sequel.pg_jsonb(rows), collected_at: now)
    end
    SearchAnalytics::MaterializedViews.refresh!(concurrently: false, force: true) unless SearchAnalytics::MaterializedViews.ready?
    SearchAnalytics::OutcomeRatesViews.refresh!(concurrently: false, force: true)
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('No collection on page reads')
  end

  it 'adds outcome fields without removing the consumed journey outcome chart or refreshing on read' do
    expect(SearchAnalytics::MaterializedViews).not_to receive(:refresh!)
    expect(SearchAnalytics::OutcomeRatesViews).not_to receive(:refresh!)
    expect(SearchAnalytics::DailyQuery).not_to receive(:call)

    get '/uk/admin/search_analytics.json', params: { period: '24h', view: 'all' }, headers: request_headers(format: :json)

    expect(response).to have_http_status(:ok)
    attributes = JSON.parse(response.body).fetch('data').fetch('attributes')
    expect(attributes.dig('journeys', 'outcomes')).to include('completed' => 1)
    expect(attributes.dig('outcome_rates', 'classic', 'counts')).to eq('results' => 0, 'no_results' => 1)
    expect(attributes.dig('outcome_rates', 'classic', 'percentages')).to eq('results' => 0.0, 'no_results' => 100.0)
    expect(attributes['question_outcomes']).to include('supported' => true)
    expect(attributes.dig('outcome_rates', 'limitations').join).to include('result_count', 'page_visible', 'answer_submitted')
    expect(response.body).not_to include('classic-search')
  end
end
