RSpec.describe SearchAnalytics::DailyQuery do
  let(:client) { Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true) }
  let(:options) { { reporting_date: Date.new(2026, 9, 14), now: Time.utc(2026, 9, 15), region: 'eu-west-2', log_group_name: 'example-logs', queries: %w[frontend_events], client: } }
  let(:row) { { 'request_id' => 'private-journey', '@timestamp' => '2026-09-14 10:00:00', 'outcome' => 'results', 'event_count' => '1', 'reported_questions' => '2', 'navigation_total_ms' => '0', 'navigation_observations' => '0' } }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    client.stub_responses(:start_query, query_id: 'frontend-query')
    client.stub_responses(:get_query_results, response([row]))
  end

  def response(rows, matched: rows.sum { |item| item['event_count'].to_i })
    { status: 'Complete', results: rows.map { |item| item.map { |field, value| { field:, value: } } }, statistics: { records_matched: matched.to_f } }
  end

  def collect = described_class.call(**options)
  def starts = client.api_requests.select { |request| request[:operation_name] == :start_query }

  it 'collects only bounded UK frontend events and stores hashed journey identifiers' do
    result = collect.fetch('frontend_events').first
    expect(result).to include('journey_key' => Digest::SHA256.hexdigest('private-journey'), 'event_count' => '1')
    expect(result).not_to have_key('request_id')
    expect(result).not_to have_key('browser_session_id')
    sql = starts.first[:params][:query_string]
    expect(sql).to include('ecs/frontend/', "event = 'guided_search.journey'", 'schema_version = 1', '2026-09-14 00:00:00', '2026-09-15 00:00:00')
    expect(sql).not_to include('backend-uk/', 'worker-uk/', 'search_degraded')
    expect(sql).to include("GET_JSON_OBJECT(REGEXP_EXTRACT(`@message`, '([{].*[}])', 1), '$.request_id')", "'$.schema_version'", "'$.browser_session_id'", "'$.result_rank'", "'$.confidence'")
    expect(sql).to include("GROUP BY request_id, DATE_TRUNC('HOUR', `@timestamp`), outcome, COALESCE(destination, ''), result_rank, confidence, browser_session_id")
  end

  it 'hashes browser session identifiers before storing them' do
    session = "v1:#{'a' * 64}"
    client.stub_responses(:get_query_results, response([row.merge('browser_session_id' => session)]))
    result = collect.fetch('frontend_events').first
    expect(result).to include('session_key' => Digest::SHA256.hexdigest(session))
    expect(result).not_to have_key('browser_session_id')
    expect(SearchAnalyticsQueryResult.first.rows.to_json).not_to include(session)
  end

  it 'does not store a session key for a malformed browser session identifier' do
    client.stub_responses(:get_query_results, response([row.merge('browser_session_id' => 'v1:session')]))
    result = collect.fetch('frontend_events').first
    expect(result).not_to have_key('session_key')
    expect(result).not_to have_key('browser_session_id')
  end

  it 'reuses a successful result without another AWS submission' do
    expected = collect
    expect(collect).to eq(expected)
    expect(starts.size).to eq(1)
    expect(SearchAnalyticsQueryResult.first.rows.to_json).not_to include('private-journey')
  end

  it 'does not offer UK-only guided events to XI collection' do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    expect { collect }.to raise_error(ArgumentError, /known daily query/)
    expect(described_class.new(**options.except(:queries)).query_definitions.size).to eq(9)
    expect(starts).to be_empty
  end

  it 'rejects missing completeness statistics without saving results' do
    client.stub_responses(:get_query_results, response([row]).merge(statistics: {}))
    expect { collect }.to raise_error(described_class::QueryError, /completeness statistics/)
    expect(SearchAnalyticsQueryResult.count).to eq(0)
  end

  it 'partitions incomplete output and discards the parent, including below the row limit' do
    client.stub_responses(:get_query_results, [response([row], matched: 2), response([row]), response([row])])
    expect(collect.fetch('frontend_events').size).to eq(2)
    expect(starts.size).to eq(3)
    expect(starts[1][:params][:query_string]).to include("`@timestamp` < CAST('2026-09-14 12:00:00'")
    expect(starts[2][:params][:query_string]).to include("`@timestamp` >= CAST('2026-09-14 12:00:00'")
  end

  it 'splits capped output into disjoint metric windows' do
    stub_const("#{described_class}::ROW_LIMIT", 2)
    client.stub_responses(:get_query_results, [response([row, row]), response([row]), response([row])])
    expect(collect.fetch('frontend_events').size).to eq(2)
    expect(starts.map { |request| request[:params].values_at(:start_time, :end_time) }).to eq([
      [Time.utc(2026, 9, 14).to_i, Time.utc(2026, 9, 15).to_i],
      [Time.utc(2026, 9, 14).to_i, Time.utc(2026, 9, 14, 12).to_i],
      [Time.utc(2026, 9, 14, 12).to_i, Time.utc(2026, 9, 15).to_i],
    ])
  end

  it 'retains the previous success when a forced collection fails' do
    collect
    original = SearchAnalyticsQueryResult.first.values
    client.stub_responses(:get_query_results, status: 'Failed')
    expect { described_class.call(**options, force: true) }.to raise_error(described_class::QueryError)
    expect(SearchAnalyticsQueryResult.first.values).to eq(original)
  end
end
