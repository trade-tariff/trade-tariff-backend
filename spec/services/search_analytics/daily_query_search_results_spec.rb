RSpec.describe SearchAnalytics::DailyQuery do
  let(:db) { Sequel::Model.db }
  let(:collector) { described_class.new(reporting_date: Date.new(2026, 9, 14), region: 'eu-west-2', log_group_name: 'search_events', now: Time.utc(2026, 9, 15)) }
  let(:columns) do
    { request_id: 'text',
      service: 'text',
      event: 'text',
      search_type: 'text',
      request_source: 'text',
      result_count: 'bigint',
      commodity_result_count: 'bigint',
      final_result_type: 'text',
      results_type: 'text',
      search_degraded: 'boolean',
      '@logStream': 'text' }
  end

  before { allow(TradeTariffBackend).to receive(:service).and_return('uk') }

  def event(id, **attributes)
    { request_id: id,
      service: 'search',
      event: 'search_completed',
      search_type: 'classic',
      request_source: 'frontend',
      result_count: 1,
      commodity_result_count: 1,
      final_result_type: nil,
      results_type: 'fuzzy_search',
      search_degraded: false,
      '@logStream': 'ecs/backend-uk/test' }.merge(attributes)
  end

  def execute(*events)
    values = events.map { |row| "(#{columns.map { |name, type| "#{db.literal(row.fetch(name))}::#{type}" }.join(', ')})" }
    names = columns.keys.map { |name| db.literal(Sequel.identifier(name)) }.join(', ')
    # Execute the actual collection predicates, including the failure cohort.
    # Only CloudWatch identifier quoting differs from PostgreSQL here.
    sql = collector.query_definitions.fetch('search_results').tr('`', '"')
    db.fetch("WITH search_events(#{names}) AS (VALUES #{values.join(', ')}) #{sql}").all
  end

  it 'counts empty fuzzy responses, but not exact matches or heading-only results as empty' do
    rows = execute(
      event('empty', result_count: 0, commodity_result_count: 0),
      event('headings', result_count: 2, commodity_result_count: 0),
      event('chapters', result_count: 1, commodity_result_count: 0),
      event('commodity'), event('exact', results_type: 'exact_search'),
      event('unknown', results_type: nil), event('missing-count', result_count: nil), event('invalid-count', result_count: -1)
    )
    expect(rows).to eq([{ search_type: 'classic', request_source: 'frontend', searches: 4, zero_results: 1 }])
  end

  it 'counts guided terminal retrievals, including legacy completions, without question steps or exact matches' do
    rows = execute(
      event('guided', search_type: 'interactive', results_type: 'hybrid', final_result_type: 'questions', result_count: 0),
      event('guided', search_type: 'interactive', results_type: 'hybrid', final_result_type: 'answers'),
      event('exact', search_type: 'interactive', results_type: 'exact_match'),
      event('error', search_type: 'interactive', results_type: 'hybrid', final_result_type: 'error', result_count: 0),
      event('legacy-empty', search_type: 'internal', results_type: 'opensearch', result_count: 0),
      event('legacy-vector', search_type: 'internal', results_type: 'vector', final_result_type: ''),
      event('unknown-terminal', search_type: 'internal', results_type: 'vector', final_result_type: 'unknown'),
    )
    expect(rows).to contain_exactly(
      { search_type: 'interactive', request_source: 'frontend', searches: 1, zero_results: 0 },
      { search_type: 'internal', request_source: 'frontend', searches: 2, zero_results: 1 },
    )
  end

  it 'excludes failed and degraded requests and non-frontend or non-UK events' do
    rows = execute(
      event('healthy'), event(nil, result_count: 0),
      event('failed', result_count: 0), event('failed', event: 'search_failed'),
      event('stage-failed', result_count: 0), event('stage-failed', event: 'search_stage_failed'),
      event(nil, search_degraded: true), event('degraded', search_degraded: true),
      event('worker', '@logStream': 'ecs/worker-uk/test'),
      event('xi', '@logStream': 'ecs/backend-xi/test'),
      event('admin', request_source: 'admin'), event('mcp', request_source: 'mcp'),
      event('unknown-source', request_source: nil), event('selection', event: 'result_selected'),
      event('classification', search_type: 'classification')
    )
    expect(rows).to eq([{ search_type: 'classic', request_source: 'frontend', searches: 3, zero_results: 1 }])
  end

  it 'leaves existing fingerprints intact when adding the independent query' do
    current = collector.fingerprints
    original = collector.query_definitions.except('search_results')
    allow(collector).to receive(:query_definitions).and_return(original)
    expect(current.except('search_results')).to eq(collector.fingerprints)
  end

  it 'collects and regenerates only the selected metric' do
    client = Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true)
    client.stub_responses(:start_query, query_id: 'search-results')
    client.stub_responses(:get_query_results, status: 'Complete', results: [], statistics: { records_matched: 0.0 })
    options = { reporting_date: Date.new(2026, 9, 14), region: 'eu-west-2', now: Time.utc(2026, 9, 15), client: }
    described_class.call(**options, queries: %w[volume])
    original = SearchAnalyticsQueryResult.where(name: 'volume').first.values
    2.times { described_class.call(**options, queries: %w[search_results], force: true) }
    expect(SearchAnalyticsQueryResult.where(name: 'volume').first.values).to eq(original)
    expect(SearchAnalyticsQueryResult.select_map(:name)).to contain_exactly('volume', 'search_results')
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(3)
  end
end
