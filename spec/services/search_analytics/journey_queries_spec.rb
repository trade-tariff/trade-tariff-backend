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

  it 'requires nonempty journey IDs' do
    expect(queries.journeys).to include("request_id IS NOT NULL AND request_id != ''")
  end
end
