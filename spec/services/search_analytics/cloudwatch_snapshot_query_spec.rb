RSpec.describe SearchAnalytics::CloudwatchSnapshotQuery do
  subject(:payloads) do
    described_class.call(
      period: '24h',
      client: client,
      now: now,
    )
  end

  let(:client) { instance_double(Aws::CloudWatchLogs::Client) }
  let(:now) { Time.zone.parse('2026-06-10 10:00:00 UTC') }

  before do
    allow(client).to receive(:start_query).and_return(
      start_query_response('volume'),
      start_query_response('zero'),
      start_query_response('summary_latency_all'),
      start_query_response('summary_latency_by_view'),
      start_query_response('source_latency_all'),
      start_query_response('source_latency_by_view'),
      start_query_response('ai_cost_summary'),
      start_query_response('ai_cost_trend'),
      start_query_response('classic_selections'),
      start_query_response('internal_selections'),
      start_query_response('classic_selection_trend'),
      start_query_response('internal_selection_trend'),
      start_query_response('search_term_terms'),
      start_query_response('item_id_terms'),
    )
    allow(client).to receive(:get_query_results).and_return(
      complete_response(
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'event' => 'search_completed', 'request_source' => 'frontend', 'searches' => '35'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'event' => 'search_completed', 'request_source' => 'backend_only', 'searches' => '7'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'event' => 'search_completed', 'searches' => '5'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'interactive', 'event' => 'search_completed', 'request_source' => 'frontend', 'searches' => '8'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'event' => 'search_failed', 'request_source' => 'frontend', 'searches' => '2'),
      ),
      complete_response(
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'request_source' => 'frontend', 'zero_results' => '3'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'request_source' => 'backend_only', 'zero_results' => '1'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'zero_results' => '1'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'interactive', 'request_source' => 'frontend', 'zero_results' => '1'),
      ),
      complete_response(result_row('p90_latency_ms' => '1000.0')),
      complete_response(
        result_row('search_type' => 'classic', 'p90_latency_ms' => '700'),
        result_row('search_type' => 'interactive', 'p90_latency_ms' => '2100'),
      ),
      complete_response(
        result_row('request_source' => 'frontend', 'p90_latency_ms' => '1200.0'),
        result_row('request_source' => 'backend_only', 'p90_latency_ms' => '800.0'),
        result_row('p90_latency_ms' => '600.0'),
      ),
      complete_response(
        result_row('search_type' => 'classic', 'request_source' => 'frontend', 'p90_latency_ms' => '900'),
        result_row('search_type' => 'classic', 'request_source' => 'backend_only', 'p90_latency_ms' => '800'),
        result_row('search_type' => 'classic', 'p90_latency_ms' => '600'),
        result_row('search_type' => 'interactive', 'request_source' => 'frontend', 'p90_latency_ms' => '2100'),
      ),
      complete_response(
        result_row(
          'aggregated_total_cost_usd' => '0.0102',
          'aggregated_average_cost_usd' => '0.0051',
          'aggregated_p50_cost_usd' => '0.0048',
          'aggregated_p90_cost_usd' => '0.0075',
          'aggregated_assisted_searches' => '2',
          'aggregated_priced_calls' => '4',
          'aggregated_unpriced_calls' => '1',
        ),
      ),
      complete_response(
        result_row(
          '@timestamp' => '2026-06-10 09:00:00.000',
          'event_kind' => 'interactive_search',
          'aggregated_input_cost_usd' => '0.004',
          'aggregated_cached_input_cost_usd' => '0.0002',
          'aggregated_cache_write_input_cost_usd' => '0.0005',
          'aggregated_output_cost_usd' => '0.006',
          'aggregated_embedding_cost_usd' => '0',
          'aggregated_total_cost_usd' => '0.01',
          'aggregated_input_tokens' => '2000',
          'aggregated_cached_input_tokens' => '400',
          'aggregated_cache_write_input_tokens' => '200',
          'aggregated_output_tokens' => '500',
          'aggregated_total_tokens' => '2500',
          'aggregated_calls' => '4',
          'aggregated_priced_calls' => '3',
          'aggregated_unpriced_calls' => '1',
        ),
        result_row(
          '@timestamp' => '2026-06-10 09:00:00.000',
          'event_kind' => 'vector_search_query_embedding',
          'aggregated_input_cost_usd' => '0',
          'aggregated_cached_input_cost_usd' => '0',
          'aggregated_cache_write_input_cost_usd' => '0',
          'aggregated_output_cost_usd' => '0',
          'aggregated_embedding_cost_usd' => '0.0002',
          'aggregated_total_cost_usd' => '0.0002',
          'aggregated_input_tokens' => '10000',
          'aggregated_cached_input_tokens' => '0',
          'aggregated_cache_write_input_tokens' => '0',
          'aggregated_output_tokens' => '0',
          'aggregated_total_tokens' => '10000',
          'aggregated_calls' => '1',
          'aggregated_priced_calls' => '1',
          'aggregated_unpriced_calls' => '0',
        ),
      ),
      complete_response(
        result_row('source' => 'frontend', 'selected' => '2', 'selectable' => '35'),
        result_row('source' => 'backend_only', 'selected' => '1', 'selectable' => '7'),
        result_row('selected' => '1', 'selectable' => '5'),
      ),
      complete_response(result_row('source' => 'frontend', 'selected' => '2', 'selectable' => '8')),
      complete_response(result_row('@timestamp' => '2026-06-10 09:00:00.000', 'selected' => '4')),
      complete_response(result_row('@timestamp' => '2026-06-10 09:00:00.000', 'selected' => '2')),
      complete_response(
        result_row('query' => 'scarf', 'search_type' => 'classic', 'zero_results' => '5'),
        result_row('query' => 'running shoes', 'search_type' => 'classic', 'zero_results' => '4'),
      ),
      complete_response(
        result_row('query' => '0101210000', 'search_type' => 'classic', 'zero_results' => '7'),
      ),
    )
  end

  describe '.query_definitions' do
    subject(:definitions) { described_class.query_definitions(period: '24h') }

    it 'returns every named query executed by the snapshot' do
      expect(definitions.keys).to contain_exactly(
        'volume',
        'zero_results',
        'summary_all_latency',
        'summary_view_latency',
        'source_all_latency',
        'source_view_latency',
        'ai_cost_summary',
        'ai_cost_trend',
        'classic_selections',
        'internal_selections',
        'classic_selection_trend',
        'internal_selection_trend',
        'search_term_improvements',
        'item_id_improvements',
      )
      expect(definitions.values).to all(be_a(String).and(be_present))
    end

    it 'excludes complete failed request cohorts within the selected backend stream' do
      queries = described_class.query_definitions(period: '24h', log_group_name: 'validation-search')

      expect(queries.values).to all(include('FROM `validation-search`', "request_id IS NULL OR request_id = '' OR request_id NOT IN ("))
      expect(queries.values).to all(include("service = 'search'", "search_degraded = true OR event IN ('search_failed', 'search_stage_failed')"))
      expect(queries.values.map { |query| query.scan("`@logStream` LIKE '%ecs/backend-uk/%'").size }).to all(eq(2))
    end

    it 'defines zero results separately for classic and interactive/internal search' do
      expect(
        [
          definitions.fetch('zero_results'),
          definitions.fetch('search_term_improvements'),
          definitions.fetch('item_id_improvements'),
        ],
      ).to all(include(
                 "search_type = 'classic'",
                 'commodity_result_count = 0',
                 "results_type != 'exact_search'",
                 'commodity_result_count IS NULL AND result_count = 0',
                 "search_type = 'interactive' OR search_type = 'internal'",
                 'result_count = 0',
               ))
    end
  end

  it 'executes SQL in the period window without an API log-group selector' do
    payloads

    expect(client).to have_received(:start_query).with(
      hash_including(start_time: (now - 24.hours).to_i, end_time: now.to_i, query_language: 'SQL'),
    ).exactly(14).times
    expect(client).not_to have_received(:start_query).with(hash_including(:log_group_name))
  end

  it 'keeps request-level cost and selection aggregates before cohort exclusion' do
    queries = described_class.query_definitions(period: '24h')

    expect(queries.fetch('ai_cost_summary')).to include('AS request_costs', 'aggregated_assisted_searches')
    expect(queries.fetch('ai_cost_trend')).to include('aggregated_embedding_cost_usd', "DATE_TRUNC('HOUR', `@timestamp`)")
    expect(queries.fetch('classic_selections')).to include("search_type = 'classic' AND results_type = 'fuzzy_search'", "GET_JSON_OBJECT(`@message`, '$.request_source')")
    expect(queries.fetch('internal_selections')).to include("results_type IN ('opensearch', 'vector', 'hybrid')")
    expect(queries.fetch('classic_selection_trend')).to include("DATE_TRUNC('HOUR', latest_timestamp) AS `@timestamp`")
    expect(queries.fetch('classic_selections')).to match(/GROUP BY request_id\s+\) AS request_selections\s+WHERE selectable_searches > 0 AND \(request_id IS NULL/)
  end

  it 'scopes CloudWatch queries to the current backend service log stream' do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')

    payloads

    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including("`@logStream` LIKE '%ecs/backend-xi/%'"),
      ),
    ).exactly(14).times
  end

  it 'raises terminal unknown CloudWatch query statuses immediately' do
    allow(client).to receive_messages(
      start_query: start_query_response('unknown'),
      get_query_results: query_response('Unknown'),
    )

    expect { payloads }.to raise_error(described_class::QueryError, 'CloudWatch query Unknown')
  end

  it 'preserves existing query errors' do
    query_error = described_class::QueryError.new('CloudWatch query Failed')

    allow(client).to receive(:start_query).and_raise(query_error)

    expect { payloads }.to raise_error(described_class::QueryError) { |error| expect(error).to equal(query_error) }
  end

  it 'builds all dashboard views without raw search rows', :aggregate_failures do
    expect(payloads.keys).to contain_exactly('all', 'classic', 'internal')
    expect(payloads.dig('all', 'summary')).to include(
      'searches' => 57,
      'failure_rate' => 0.04,
      'zero_result_rate' => 0.11,
      'selection_rate' => 0.11,
      'p90_latency_ms' => 1000,
    )
    payloads.each_value do |payload|
      expect(payload.dig('summary_statuses', 'failure_rate')).to eq(
        'level' => 'neutral',
        'message' => 'Known failed or degraded requests are excluded',
      )
    end
    expect(payloads.dig('all', 'comparisons', 'classic')).to include(
      'searches' => 49,
      'zero_result_rate' => 0.11,
      'p90_latency_ms' => 700,
    )
    expect(payloads.dig('all', 'request_sources', 'frontend')).to include(
      'searches' => 45,
      'failure_rate' => 0.04,
      'zero_result_rate' => 0.09,
      'selection_rate' => 0.09,
      'p90_latency_ms' => 1200,
    )
    expect(payloads.dig('all', 'request_sources', 'backend_only')).to include(
      'searches' => 7,
      'failure_rate' => 0.0,
      'zero_result_rate' => 0.14,
      'selection_rate' => 0.14,
      'p90_latency_ms' => 800,
    )
    expect(payloads.dig('all', 'request_sources', 'unknown')).to include(
      'searches' => 5,
      'failure_rate' => 0.0,
      'zero_result_rate' => 0.2,
      'selection_rate' => 0.2,
      'p90_latency_ms' => 600,
    )
    expect(payloads.dig('all', 'trends', 'volume')).to contain_exactly(
      {
        'bucket' => '2026-06-10T09:00:00Z',
        'all' => 57,
        'classic' => 49,
        'internal' => 8,
        'frontend' => 45,
        'backend_only' => 7,
        'unknown' => 5,
      },
    )
    expect(payloads.dig('all', 'trends', 'outcomes')).to contain_exactly(
      {
        'bucket' => '2026-06-10T09:00:00Z',
        'completed' => 55,
        'failed' => 2,
        'zero_result' => 6,
        'selected' => 6,
      },
    )
    expect(payloads.dig('all', 'ai_costs', 'summary')).to include(
      'total_cost_usd' => 0.0102,
      'assisted_searches' => 2,
      'average_cost_usd' => 0.0051,
      'p50_cost_usd' => 0.0048,
      'p90_cost_usd' => 0.0075,
      'pricing_coverage' => 0.8,
      'complete' => false,
    )
    expect(payloads.dig('all', 'ai_costs', 'trend')).to contain_exactly(
      {
        'bucket' => '2026-06-10T09:00:00Z',
        'input_cost_usd' => 0.004,
        'cached_input_cost_usd' => 0.0002,
        'cache_write_input_cost_usd' => 0.0005,
        'output_cost_usd' => 0.006,
        'embedding_cost_usd' => 0.0002,
        'total_cost_usd' => 0.0102,
      },
    )
    expect(payloads.dig('all', 'ai_costs', 'operations')).to match(
      [
        include('event_kind' => 'interactive_search', 'calls' => 4, 'total_tokens' => 2500, 'cached_input_tokens' => 400, 'cache_write_input_tokens' => 200, 'input_cost_usd' => 0.004, 'cached_input_cost_usd' => 0.0002, 'cache_write_input_cost_usd' => 0.0005, 'output_cost_usd' => 0.006, 'embedding_cost_usd' => 0.0, 'total_cost_usd' => 0.01, 'unpriced_calls' => 1),
        include('event_kind' => 'vector_search_query_embedding', 'calls' => 1, 'total_tokens' => 10_000, 'input_cost_usd' => 0.0, 'output_cost_usd' => 0.0, 'embedding_cost_usd' => 0.0002, 'total_cost_usd' => 0.0002, 'unpriced_calls' => 0),
      ],
    )
    expect(payloads.dig('classic', 'ai_costs')).to include(
      'summary' => include('total_cost_usd' => 0.0, 'assisted_searches' => 0),
      'trend' => [],
      'operations' => [],
    )
    expect(payloads.dig('classic', 'trends', 'outcomes')).to contain_exactly(
      include(
        'bucket' => '2026-06-10T09:00:00Z',
        'selected' => 4,
      ),
    )
    expect(payloads.dig('all', 'improvement_terms')).to include(
      include('query' => '0101210000', 'zero_results' => 7, 'term_type' => 'item_ids'),
      include('query' => 'scarf', 'zero_results' => 5, 'term_type' => 'search_terms'),
      include('query' => 'running shoes', 'zero_results' => 4, 'term_type' => 'search_terms'),
    )
    expect(payloads.dig('all', 'improvement_terms')).to all(satisfy { |term| term.keys.exclude?('searches') && term.keys.exclude?('selection_rate') })
  end

  def start_query_response(query_id)
    instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: query_id)
  end

  def complete_response(*results)
    query_response('Complete', results:)
  end

  def query_response(status, results: [])
    instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status:, results:)
  end

  def result_row(fields)
    fields.map { |field, value| instance_double(Aws::CloudWatchLogs::Types::ResultField, field: field, value: value) }
  end
end
