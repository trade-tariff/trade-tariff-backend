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
      start_query_response('latency_all'),
      start_query_response('latency_by_view'),
      start_query_response('classic_selections'),
      start_query_response('internal_selections'),
      start_query_response('classic_selection_trend'),
      start_query_response('internal_selection_trend'),
      start_query_response('terms'),
      start_query_response('non_numeric_terms'),
      start_query_response('numeric_terms'),
    )
    allow(client).to receive(:get_query_results).and_return(
      complete_response(
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'event' => 'search_completed', 'searches' => '42'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'interactive', 'event' => 'search_completed', 'searches' => '8'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'event' => 'search_failed', 'searches' => '2'),
      ),
      complete_response(
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'classic', 'zero_results' => '4'),
        result_row('@timestamp' => '2026-06-10 09:00:00.000', 'search_type' => 'interactive', 'zero_results' => '1'),
      ),
      complete_response(result_row('p90_latency_ms' => '1200')),
      complete_response(
        result_row('search_type' => 'classic', 'p90_latency_ms' => '900'),
        result_row('search_type' => 'interactive', 'p90_latency_ms' => '2100'),
      ),
      complete_response(result_row('selected' => '3', 'selectable' => '42')),
      complete_response(result_row('selected' => '2', 'selectable' => '8')),
      complete_response(result_row('@timestamp' => '2026-06-10 09:00:00.000', 'selected' => '3')),
      complete_response(result_row('@timestamp' => '2026-06-10 09:00:00.000', 'selected' => '2')),
      complete_response(
        result_row('query' => 'yoga ball', 'search_type' => 'classic', 'zero_results' => '3'),
        result_row('query' => '3926909090', 'search_type' => 'classic', 'zero_results' => '2'),
      ),
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
        query_string: a_string_including('datefloor(@t, 1h) as @timestamp'),
      ),
    ).twice
    expect(client).not_to have_received(:start_query).with(
      hash_including(
        query_string: a_string_including('selected_count'),
      ),
    )
  end

  it 'builds all dashboard views without raw search rows', :aggregate_failures do
    expect(payloads.keys).to contain_exactly('all', 'classic', 'internal')
    expect(payloads.dig('all', 'summary')).to include(
      'searches' => 52,
      'failure_rate' => 0.04,
      'zero_result_rate' => 0.1,
      'selection_rate' => 0.1,
      'p90_latency_ms' => 1200,
    )
    expect(payloads.dig('all', 'comparisons', 'classic')).to include(
      'searches' => 44,
      'zero_result_rate' => 0.1,
    )
    expect(payloads.dig('all', 'trends', 'volume')).to contain_exactly(
      {
        'bucket' => '2026-06-10T09:00:00Z',
        'all' => 52,
        'classic' => 44,
        'internal' => 8,
      },
    )
    expect(payloads.dig('all', 'trends', 'outcomes')).to contain_exactly(
      {
        'bucket' => '2026-06-10T09:00:00Z',
        'completed' => 50,
        'failed' => 2,
        'zero_result' => 5,
        'selected' => 5,
      },
    )
    expect(payloads.dig('classic', 'trends', 'outcomes')).to contain_exactly(
      include(
        'bucket' => '2026-06-10T09:00:00Z',
        'selected' => 3,
      ),
    )
    expect(payloads.dig('all', 'improvement_terms')).to include(
      include('query' => '0101210000', 'zero_results' => 7),
      include('query' => 'scarf', 'zero_results' => 5),
      include('query' => 'running shoes', 'zero_results' => 4),
      include('query' => 'yoga ball', 'zero_results' => 3),
    )
  end

  def start_query_response(query_id)
    instance_double(Aws::CloudWatchLogs::Types::StartQueryResponse, query_id: query_id)
  end

  def complete_response(*results)
    instance_double(Aws::CloudWatchLogs::Types::GetQueryResultsResponse, status: 'Complete', results: results)
  end

  def result_row(fields)
    fields.map { |field, value| instance_double(Aws::CloudWatchLogs::Types::ResultField, field: field, value: value) }
  end
end
