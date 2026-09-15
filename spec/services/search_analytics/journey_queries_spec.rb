RSpec.describe SearchAnalytics::JourneyQueries do
  subject(:queries) { described_class.new(source: '`example-logs`', log_stream_filter: stream_filter) }

  let(:stream_filter) { "(`@logStream` LIKE '%ecs/backend-uk/%' OR `@logStream` LIKE '%ecs/worker-uk/%')" }

  it 'selects distinct IDs from frontend search starts, not completion or exact-match events' do
    expect(queries.journeys).to include("event = 'search_started'", "request_source = 'frontend'", 'COLLECT_SET(request_id)', 'COUNT(DISTINCT request_id)')
    expect(queries.journeys).not_to include('search_completed', 'exact_match', 'search_degraded')
  end

  it 'retains service scope, hourly identity sets and completeness counts' do
    expect(queries.journeys).to include(stream_filter, 'FROM `example-logs`', "DATE_TRUNC('HOUR'", 'COUNT(*) AS started_events', 'LIMIT 10000')
  end

  it 'requires nonempty IDs for both journey extraction and call-cost summaries' do
    expect(queries.journeys).to include("request_id IS NOT NULL AND request_id != ''")
    expect(queries.cost_summary(cost_filter: "event = 'api_call_completed'")).to include("request_id IS NOT NULL AND request_id != ''")
  end

  it 'includes recorded failures and missing usage without filtering costs by source' do
    sql = queries.cost_summary(cost_filter: "event = 'api_call_completed'")
    expect(sql).to include(stream_filter, 'pricing_known = true', 'total_cost_usd IS NOT NULL', 'aggregated_unpriced_calls', 'GROUP BY request_id')
    expect(sql).not_to include('request_source', 'search_degraded', 'total_tokens', 'search_completed')
  end

  it 'keeps grouped IDs and IN predicates out of conditional aggregates' do
    predicates = queries.cost_summary(cost_filter: "event = 'api_call_completed'").scan(/CASE WHEN (.*?) THEN/m).flatten
    expect(predicates).not_to include(a_string_matching(/request_id|\bIN\s*\(/))
  end
end
