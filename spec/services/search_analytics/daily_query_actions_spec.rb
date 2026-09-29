RSpec.describe SearchAnalytics::DailyQuery do
  let(:client) { Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true) }
  let(:options) { { reporting_date: Date.new(2026, 9, 14), now: Time.utc(2026, 9, 15), region: 'eu-west-2', log_group_name: 'example-logs', queries: %w[search_actions], client: } }
  let(:empty) { { status: 'Complete', results: [], statistics: { records_matched: 0.0 } } }
  let(:rows) do
    [
      { 'request_ids' => '["classic-id"]', 'journey_count' => '1', 'event_count' => '2', 'request_source' => 'frontend', 'search_type' => 'classic', 'search_action' => 'navigation' },
      { 'request_ids' => '["internal-id"]', 'journey_count' => '1', 'event_count' => '1', 'request_source' => 'frontend', 'search_type' => 'internal', 'search_action' => 'search' },
    ]
  end

  before do
    client.stub_responses(:start_query, query_id: 'actions-query')
    client.stub_responses(:get_query_results, [response(rows), *Array.new(7) { empty }])
  end

  def response(values)
    empty.merge(results: values.map { |row| row.map { |field, value| { field:, value: } } }, statistics: { records_matched: 3.0 })
  end

  def collect = described_class.call(**options).fetch('search_actions')
  def starts = client.api_requests.select { |request| request[:operation_name] == :start_query }

  it 'stores both types with hashed identities' do
    expect(collect).to contain_exactly(
      include('search_type' => 'classic', 'search_action' => 'navigation', 'journey_keys' => [Digest::SHA256.hexdigest('classic-id')]),
      include('search_type' => 'internal', 'search_action' => 'search', 'journey_keys' => [Digest::SHA256.hexdigest('internal-id')]),
    )
    expect(SearchAnalyticsQueryResult.first.rows.to_json).not_to include('request_ids', 'classic-id', 'internal-id')
    expect(starts.size).to eq(8)
  end

  it 'uses explicit frontend actions without a version filter' do
    sql = described_class.new(**options).query_definitions.fetch('search_actions')
    expect(sql).to include("event = 'search_action_classified'", "request_source = 'frontend'", 'GROUP BY search_type, request_source, search_action')
    expect(sql).not_to include('search_action_version', 'exact_match', 'result_selected', 'search_degraded', 'query RLIKE')
  end

  it 'keeps existing query fingerprints' do
    collector = described_class.new(**options)
    current = collector.fingerprints
    existing = collector.query_definitions.except('search_actions')
    allow(collector).to receive(:query_definitions).and_return(existing)
    expect(collector.fingerprints).to eq(current.except('search_actions'))
  end

  it 'reuses stored actions without scanning' do
    expected = collect
    expect(collect).to eq(expected)
    expect(starts.size).to eq(8)
  end

  it 'splits incomplete identifier sets' do
    incomplete = rows.map { |row| row.merge('request_ids' => '[]') }
    client.stub_responses(:get_query_results, [response(incomplete), response(rows), empty, *Array.new(7) { empty }])
    expect(collect.size).to eq(2)
    expect(starts.size).to eq(10)
  end

  it 'rejects missing collection statistics' do
    client.stub_responses(:get_query_results, response(rows).merge(statistics: {}))
    expect { collect }.to raise_error(described_class::QueryError, /completeness statistics/)
    expect(SearchAnalyticsQueryResult.where(name: 'search_actions')).to be_empty
  end

  it 'preserves stored data on failed refresh' do
    collect
    previous = SearchAnalyticsQueryResult.first.values
    client.stub_responses(:get_query_results, status: 'Failed')
    expect { described_class.call(**options, force: true) }.to raise_error(described_class::QueryError)
    expect(SearchAnalyticsQueryResult.first.values).to eq(previous)
  end
end
