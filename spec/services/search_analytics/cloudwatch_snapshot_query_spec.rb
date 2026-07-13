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

  it 'uses aggregate CloudWatch stats queries for the period window' do
    payloads

    expect(client).to have_received(:start_query).with(
      hash_including(
        start_time: (now - 24.hours).to_i,
        end_time: now.to_i,
        query_string: a_string_including('| stats'),
      ),
    ).at_least(:once)
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('filter @logStream like "ecs/backend-uk/"'),
      ),
    ).exactly(12).times
    expect(client).not_to have_received(:start_query).with(
      hash_including(query_string: a_string_including('sort bin(')),
    )
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('search_type = "classic" and results_type = "fuzzy_search"'),
      ),
    ).twice
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('event = "result_selected" or (event = "search_completed"'),
      ),
    ).exactly(4).times
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('results_type = "opensearch" or results_type = "vector" or results_type = "hybrid"'),
      ),
    ).twice
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('max(@timestamp) as @t by request_id'),
      ),
    ).twice
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('earliest(request_source) as source by request_id'),
      ),
    ).exactly(2).times
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('earliest(request_source) as source, max(@timestamp) as @t by request_id'),
      ),
    ).twice
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('| stats sum(result_selections) as selected, sum(selectable_searches) as selectable by source'),
      ),
    ).twice
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('datefloor(@t, 1h) as @timestamp'),
      ),
    ).twice
    expect(client).not_to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('earliest(request_source) as request_source by request_id'),
      ),
    )
    expect(client).not_to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('sum(selectable_searches) as selectable by request_source'),
      ),
    )
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_matching(/stats pct\(total_duration_ms, 90\) as p90_latency_ms\s*$/),
      ),
    ).once
    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('stats pct(total_duration_ms, 90) as p90_latency_ms by request_source'),
      ),
    ).once
    expect(client).not_to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('selected_count'),
      ),
    )
  end

  it 'scopes CloudWatch queries to the current backend service log stream' do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')

    payloads

    expect(client).to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('filter @logStream like "ecs/backend-xi/"'),
      ),
    ).exactly(12).times
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
