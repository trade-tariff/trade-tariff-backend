RSpec.describe SearchAnalytics::DailyQuery do
  let(:client) { Aws::CloudWatchLogs::Client.new(region: 'eu-west-2', stub_responses: true) }
  let(:options) { { reporting_date: Date.new(2026, 9, 14), region: 'eu-west-2', log_group_name: 'example-logs', now: Time.utc(2026, 9, 15, 4), client: } }
  let(:complete) { { status: 'Complete', results: [], statistics: { records_matched: 0.0 } } }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    client.stub_responses(:start_query, Array.new(100) { |i| { query_id: "query-#{i}" } })
    client.stub_responses(:get_query_results, complete)
  end

  def collector(**extra) = described_class.new(**options, **extra)
  def starts = client.api_requests.select { |r| r[:operation_name] == :start_query }
  def collect(**extra) = collector(**extra).call
  def encoded(row) = row.map { |field, value| { field:, value: value.to_s } }

  it 'stores ten complete logical query groups and reuses them without another scan' do
    rows = collect
    expect(rows.size).to eq(10)
    expect(starts.size).to eq(24)
    expect(SearchAnalyticsQueryResult.count).to eq(10)
    expect(collect).to eq(rows)
    expect(starts.size).to eq(24)
    expect(rows).not_to have_key('ai_cost_summary')
  end

  it 'can plan reusable results without constructing an AWS client' do
    collect
    expect(Aws::CloudWatchLogs::Client).not_to receive(:new)
    expect(collector(client: nil).plan.values).to eq(%w[reuse] * 10)
    expect(collector(client: nil).call.values).to eq([[]] * 10)
  end

  it 'reruns only the missing query after a later query fails' do
    client.stub_responses(:get_query_results, [*Array.new(7) { complete }, complete.merge(status: 'Failed')])
    expect { collect }.to raise_error(described_class::QueryError, /Failed/)
    expect(SearchAnalyticsQueryResult.count).to eq(7)
    client.stub_responses(:get_query_results, complete)
    collect
    expect(starts.size).to eq(25)
    expect(SearchAnalyticsQueryResult.count).to eq(10)
  end

  it 'forces only the selected query and preserves other results' do
    collect
    ids = SearchAnalyticsQueryResult.where(name: 'volume').select_map(:id)
    collect(queries: %w[ai_cost_trend], force: true)
    expect(starts.size).to eq(25)
    expect(SearchAnalyticsQueryResult.where(name: 'volume').select_map(:id)).to eq(ids)
  end

  it 'collects a selected query independently when other results are still missing' do
    expect(collect(queries: %w[volume])).to eq('volume' => [])
    expect(starts.size).to eq(1)
    expect(SearchAnalyticsQueryResult.select_map(:name)).to eq(%w[volume])
    expect(collector(queries: %w[volume]).plan.values.tally).to eq('reuse' => 1, 'skip' => 9)
  end

  it 'rejects unknown selections and incomplete dates without submissions' do
    expect { collector(queries: %w[unknown]) }.to raise_error(ArgumentError)
    expect { collector(reporting_date: Date.new(2026, 9, 15)) }.to raise_error(ArgumentError, /completed UTC/)
    expect { collector(region: '') }.to raise_error(ArgumentError, /Region/)
    expect { collector(log_group_name: 'invalid`group') }.to raise_error(ArgumentError, /log group/)
    expect(starts).to eq([])
  end

  it 'invalidates fingerprints when region, group, service or query definitions change' do
    baseline = collector.fingerprints
    expect(collector(region: 'eu-west-1').fingerprints).not_to eq(baseline)
    expect(collector(log_group_name: 'different-logs').fingerprints).not_to eq(baseline)
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    expect(collector.fingerprints).not_to eq(baseline)
  end

  it 'uses both selected-service streams without changing the rolling collector' do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    expect(collector.query_definitions.values).to all(include('backend-xi/', 'worker-xi/'))
    expect(collector.query_definitions.values).not_to include(a_string_including('backend-uk/'))
    legacy = SearchAnalytics::CloudwatchSnapshotQuery.query_definitions(period: '24h')
    expect(legacy.values).not_to include(a_string_including('worker-xi/'))
  end

  it 'uses half-open calendar bounds for metric scans and full-day failure cohorts' do
    collect
    expect(starts.first[:params]).to include(start_time: Time.utc(2026, 9, 14).to_i, end_time: Time.utc(2026, 9, 15).to_i, query_language: 'SQL')
    expect(starts.first[:params][:query_string]).to include("`@timestamp` >= CAST('2026-09-14 00:00:00'", "`@timestamp` < CAST('2026-09-15 00:00:00'")
    journey_sql = starts[14][:params][:query_string]
    expect(journey_sql).to include("`@timestamp` >= CAST('2026-09-14 21:00:00'", "request_source = 'frontend'")
  end

  it 'gives each initial journey scan one distinct three-hour metric window' do
    collect
    bounds = starts[7, 8].map { |request| request[:params][:query_string].scan(/`@timestamp` (?:>=|<) CAST\('([^']+)'/).flatten }
    expected = Array.new(8) do |index|
      start_at = Time.utc(2026, 9, 14) + index * 3.hours
      [start_at.strftime('%F %T'), (start_at + 3.hours).strftime('%F %T')]
    end
    expect(bounds).to eq(expected)
    expect(starts[7, 8].map { |request| request[:params].values_at(:start_time, :end_time) }).to eq(expected.map { |pair| pair.map { |value| Time.find_zone!('UTC').parse(value).to_i } })
  end

  it 'retains all model and embedding calls without token or failure-cohort filtering' do
    sql = collector.query_definitions.fetch('ai_cost_trend')
    expect(sql).to include('GROUP BY request_id', "COALESCE(event_kind, operation, 'unknown')", "COALESCE(model, 'unknown')", "event = 'embedding_api_call_failed'")
    expect(sql).not_to include('total_tokens IS NOT NULL', 'search_degraded', 'request_source')
  end

  it 'keeps zero-result counts in volume and mergeable latency counts' do
    definitions = collector.query_definitions
    expect(definitions['volume']).to include('AS zero_results')
    expect(definitions['latency_histogram']).to include('COUNT(*) AS observations', 'FLOOR(LN(total_duration_ms)')
    expect(definitions.values).not_to include(a_string_including('PERCENTILE_APPROX'))
    expect(definitions['internal_selection_trend']).to include('AS `@timestamp`, source', 'latest_timestamp), source')
  end

  it 'hashes cost request IDs before storing them and normalises operations' do
    row = encoded('request_id' => 'private-id', 'cost_operation' => 'interactive_search', 'model' => 'gpt-5.4', 'aggregated_total_cost_usd' => '0.01')
    client.stub_responses(:get_query_results, [complete, complete, complete.merge(results: [row]), *Array.new(12) { complete }])
    rows = collect.fetch('ai_cost_trend')
    expect(rows.first).to include('journey_key' => Digest::SHA256.hexdigest('private-id'), 'event_kind' => 'interactive_search', 'model' => 'gpt-5.4', 'total_cost_usd' => '0.01')
    expect(SearchAnalyticsQueryResult.all.map { |r| r.rows.to_json }.join).not_to include('private-id')
  end

  it 'hashes complete frontend journey sets before storing them' do
    row = encoded('request_ids' => '["first","second"]', 'journey_count' => '2', 'started_events' => '3', 'request_source' => 'frontend', 'search_type' => 'interactive', '@timestamp' => '2026-09-14 00:00:00')
    response = complete.merge(results: [row], statistics: { records_matched: 3.0 })
    client.stub_responses(:get_query_results, [*Array.new(7) { complete }, response, *Array.new(7) { complete }])
    result = collect.fetch('search_journeys').first
    expect(result.fetch('journey_keys')).to eq(%w[first second].map { |id| Digest::SHA256.hexdigest(id) })
    expect(result).not_to have_key('request_ids')
  end

  it 'rejects malformed or truncated journey sets without caching them' do
    row = encoded('request_ids' => '["first"]', 'journey_count' => '2', 'started_events' => '1')
    response = complete.merge(results: [row], statistics: { records_matched: 1.0 })
    client.stub_responses(:get_query_results, [*Array.new(7) { complete }, response, *Array.new(7) { complete }])
    expect { collect }.to raise_error(described_class::QueryError, /identifier set/)
    expect(SearchAnalyticsQueryResult.where(name: 'search_journeys').count).to eq(0)
  end

  it 'splits incomplete journey output even when below the row cap' do
    client.stub_responses(:get_query_results, [*Array.new(7) { complete }, complete.merge(statistics: { records_matched: 2.0 }), *Array.new(9) { complete }])
    collect
    expect(starts.size).to eq(26)
    expect(starts[8][:params][:query_string]).to include('2026-09-14 01:30:00')
    expect(starts[9][:params][:query_string]).to include('2026-09-14 01:30:00')
  end

  it 'fails safely without matched-event statistics for journey completeness' do
    client.stub_responses(:get_query_results, [*Array.new(7) { complete }, complete.merge(statistics: {})])
    expect { collect }.to raise_error(described_class::QueryError, /completeness statistics/)
    expect(SearchAnalyticsQueryResult.where(name: 'search_journeys').count).to eq(0)
  end

  it 'rejects capped histograms rather than caching a partial distribution' do
    stub_const("#{described_class}::ROW_LIMIT", 1)
    client.stub_responses(:get_query_results, [complete, complete.merge(results: [encoded('observations' => '1')])])
    expect { collect }.to raise_error(described_class::QueryError, /histogram/)
    expect(SearchAnalyticsQueryResult.count).to eq(1)
  end

  it 'splits capped term extraction while retaining the full-day exclusion cohort' do
    stub_const("#{described_class}::ROW_LIMIT", 2)
    capped = complete.merge(results: [encoded('query' => 'discard-a'), encoded('query' => 'discard-b')])
    child = complete.merge(results: [encoded('query' => 'keep', 'search_type' => 'classic', 'zero_results' => '1')])
    client.stub_responses(:get_query_results, [*Array.new(5) { complete }, capped, child, child, *Array.new(9) { complete }])
    result = collect.fetch('search_term_improvements')
    expect(result.map { |row| row['query'] }).to eq(%w[keep keep])
    expect(starts[6][:params].values_at(:start_time, :end_time)).to eq([Time.utc(2026, 9, 14).to_i, Time.utc(2026, 9, 15).to_i])
    child_sql = starts[6][:params][:query_string]
    expect(child_sql).to include("`@timestamp` < CAST('2026-09-14 12:00:00'")
    expect(child_sql).to match(/request_id NOT IN \(.*2026-09-14 00:00:00.*2026-09-15 00:00:00/m)
    expect(child_sql.scan(/`@timestamp` (?:>=|<) CAST\('([^']+)'/).flatten).to eq([
      '2026-09-14 00:00:00', '2026-09-14 12:00:00', '2026-09-14 00:00:00', '2026-09-15 00:00:00'
    ])
  end

  it 'disables automatic SDK retries when constructing the daily client' do
    existing_client = client
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(existing_client)
    collect(client: nil)
    expect(Aws::CloudWatchLogs::Client).to have_received(:new).with(region: 'eu-west-2', retry_limit: 0).once
  end

  it 'bounds recursive partitioning and keeps capped parents out of storage' do
    stub_const("#{described_class}::ROW_LIMIT", 1)
    stub_const("#{described_class}::MAX_PARTITIONS", 1)
    client.stub_responses(:get_query_results, [complete, complete, complete.merge(results: [encoded('request_id' => 'one')])])
    expect { collect }.to raise_error(described_class::QueryError, /partition limit/)
    expect(SearchAnalyticsQueryResult.count).to eq(2)
  end

  it 'does not retry a failed submission' do
    client.stub_responses(:start_query, 'ServiceUnavailableException')
    expect { collect }.to raise_error(Aws::CloudWatchLogs::Errors::ServiceUnavailableException)
    expect(starts.size).to eq(1)
    expect(SearchAnalyticsQueryResult.count).to eq(0)
  end

  it 'cancels an interrupted query without overwriting the original error' do
    client.stub_responses(:get_query_results, 'ServiceUnavailableException')
    expect { collect }.to raise_error(Aws::CloudWatchLogs::Errors::ServiceUnavailableException)
    expect(client.api_requests.map { |r| r[:operation_name] }).to include(:stop_query)
    expect(SearchAnalyticsQueryResult.count).to eq(0)
  end
end
