RSpec.describe SearchAnalytics::DailyQuery do
  let(:client) { Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true) }
  let(:options) { { reporting_date: Date.new(2026, 9, 14), now: Time.utc(2026, 9, 15), region: 'eu-west-2', log_group_name: 'example-logs', queries: %w[journey_outcomes], client: } }
  let(:row) { { 'request_ids' => '["one","two"]', 'journey_count' => '2', 'event_count' => '3', 'terminal_state' => 'completed', 'questions_seen' => '1', 'unknown_seen' => '0', 'selected' => '1', 'zero_result' => '0' } }
  let(:empty) { { status: 'Complete', results: [], statistics: { records_matched: 0.0 } } }

  before do
    client.stub_responses(:start_query, query_id: 'outcome-query')
    client.stub_responses(:get_query_results, [response(row), *Array.new(7) { empty }])
  end

  def response(item)
    { status: 'Complete', results: [item.map { |field, value| { field:, value: } }], statistics: { records_matched: 3.0 } }
  end

  def collect = described_class.call(**options).fetch('journey_outcomes')
  def starts = client.api_requests.select { |request| request[:operation_name] == :start_query }

  it 'collects failures, questions, results and selections without excluding failures or requiring downstream source markers' do
    sql = described_class.new(**options).query_definitions.fetch('journey_outcomes')
    expect(sql).to include("event = 'search_failed'", "final_result_type = 'questions'", "final_result_type = 'answers'", "final_result_type = 'error'", "results_type = 'exact_match'")
    expect(sql).to include("THEN 'conflict'", 'GROUP BY request_id', 'COLLECT_SET(request_id)', 'total_questions')
    expect(sql).not_to include('request_source', 'request_id NOT IN')
  end

  it 'recognises classification completions and preserves canonical empty-commodity semantics' do
    collector = described_class.new(**options)
    sql = collector.query_definitions.fetch('journey_outcomes')
    expect(sql).to include("search_type = 'classification'", collector.send(:zero_result_condition))
    expect(sql).to include('commodity_result_count IS NOT NULL AND commodity_result_count = 0', "results_type != 'exact_search'", "search_type = 'classification' AND result_count = 0")
    expect(sql).to include('search_degraded IS NULL OR search_degraded = false')
  end

  it 'hashes compact sets and records the actual non-overlapping collection windows' do
    result = collect
    expect(result.first).to include('journey_keys' => %w[one two].map { |id| Digest::SHA256.hexdigest(id) }, 'window_start' => '2026-09-14T00:00:00Z', 'window_end' => '2026-09-14T03:00:00Z')
    expect(result.first).not_to have_key('request_ids')
    expect(starts.size).to eq(8)
    expect(starts.first[:params][:query_string]).to include("`@timestamp` < CAST('2026-09-14 03:00:00'")
  end

  it 'splits truncated identifier sets even if event totals and the row count look complete' do
    client.stub_responses(:get_query_results, [response(row.merge('request_ids' => '["one"]')), response(row), empty, *Array.new(7) { empty }])
    expect(collect.first['window_end']).to eq('2026-09-14T01:30:00Z')
    expect(starts.size).to eq(10)
    expect(starts[2][:params][:query_string]).to include("`@timestamp` >= CAST('2026-09-14 01:30:00'")
  end

  it 'splits malformed identifier arrays and never saves the malformed parent' do
    client.stub_responses(:get_query_results, [response(row.merge('request_ids' => '["one"')), response(row), empty, *Array.new(7) { empty }])
    expect(collect.first['journey_keys'].size).to eq(2)
    expect(starts.size).to eq(10)
  end

  it 'rejects missing completeness statistics without caching outcomes' do
    client.stub_responses(:get_query_results, response(row).merge(statistics: {}))
    expect { collect }.to raise_error(described_class::QueryError, /completeness statistics/)
    expect(SearchAnalyticsQueryResult.where(name: 'journey_outcomes')).to be_empty
  end

  it 'reuses a successful collection without submitting the eight scans again' do
    expected = collect
    expect(collect).to eq(expected)
    expect(starts.size).to eq(8)
  end

  it 'does not replace prior outcomes when a forced refresh fails' do
    collect
    previous = SearchAnalyticsQueryResult.where(name: 'journey_outcomes').first.values
    client.stub_responses(:get_query_results, status: 'Failed')
    expect { described_class.call(**options, force: true) }.to raise_error(described_class::QueryError)
    expect(SearchAnalyticsQueryResult.where(name: 'journey_outcomes').first.values).to eq(previous)
  end
end
