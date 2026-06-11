RSpec.describe SearchAnalytics::SnapshotBuilder do
  subject(:payload) do
    described_class.call(
      rows: rows,
      period: '24h',
      view: 'all',
      now: now,
    )
  end

  let(:now) { Time.zone.parse('2026-06-10 10:00:00 UTC') }
  let(:rows) do
    [
      search_row('2026-06-10T09:00:00Z', 'search_completed', 'classic', 'trainers', result_count: 3, total_duration_ms: 500, request_id: 'classic-1'),
      search_row('2026-06-10T09:05:00Z', 'search_completed', 'classic', 'trainers', result_count: 0, total_duration_ms: 700, request_id: 'classic-2'),
      search_row('2026-06-10T09:06:00Z', 'result_selected', nil, nil, request_id: 'classic-1'),
      search_row('2026-06-10T09:07:00Z', 'result_selected', nil, nil, request_id: 'classic-1'),
      search_row('2026-06-10T09:10:00Z', 'search_completed', 'interactive', 'socks', result_count: 2, total_duration_ms: 2_000, request_id: 'internal-1'),
      search_row('2026-06-10T09:11:00Z', 'result_selected', nil, nil, request_id: 'internal-1'),
      search_row('2026-06-10T09:12:00Z', 'search_failed', 'interactive', 'belts', request_id: 'internal-2'),
      search_row('2026-06-10T10:00:00Z', 'search_completed', 'classic', 'boots', result_count: 1, total_duration_ms: 900, request_id: 'classic-3'),
    ]
  end

  describe '.call' do
    it 'builds summary metrics' do
      expect(payload.fetch('summary')).to include(
        'searches' => 5,
        'failure_rate' => 0.2,
        'zero_result_rate' => 0.25,
        'selection_rate' => 1.0,
        'p90_latency_ms' => 2_000,
      )
    end

    it 'builds bucketed trends' do
      expect(payload.dig('trends', 'volume')).to include(
        {
          'bucket' => '2026-06-10T09:00:00Z',
          'all' => 4,
          'classic' => 2,
          'internal' => 2,
        },
        {
          'bucket' => '2026-06-10T10:00:00Z',
          'all' => 1,
          'classic' => 1,
          'internal' => 0,
        },
      )
      expect(payload.dig('trends', 'outcomes')).to include(
        {
          'bucket' => '2026-06-10T09:00:00Z',
          'completed' => 3,
          'failed' => 1,
          'zero_result' => 1,
          'selected' => 3,
        },
      )
    end

    it 'builds view comparisons' do
      expect(payload.fetch('comparisons')).to include(
        'classic' => include(
          'searches' => 3,
          'zero_result_rate' => 0.33,
          'selection_rate' => 1.0,
          'p90_latency_ms' => 900,
        ),
        'internal' => include(
          'searches' => 2,
          'zero_result_rate' => 0.0,
          'selection_rate' => 1.0,
          'p90_latency_ms' => 2_000,
        ),
      )
    end

    it 'excludes exact matches from the selection denominator' do
      rows = [
        search_row('2026-06-10T09:00:00Z', 'search_completed', 'classic', 'exact', result_count: 1, request_id: 'exact-1', results_type: 'exact_search'),
        search_row('2026-06-10T09:01:00Z', 'result_selected', nil, nil, request_id: 'exact-1'),
      ]

      payload = described_class.call(rows:, period: '24h', view: 'all', now: now)

      expect(payload.fetch('summary')).to include('selection_rate' => 0.0)
    end

    it 'builds improvement terms from frequent zero-result queries' do
      expect(payload.fetch('improvement_terms')).to contain_exactly(
        {
          'query' => 'trainers',
          'zero_results' => 1,
        },
      )
    end

    it 'returns enough improvement terms for admin-side filtering and pagination' do
      rows = Array.new(11) do |index|
        search_row(
          "2026-06-10T09:#{index.to_s.rjust(2, '0')}:00Z",
          'search_completed',
          'classic',
          "zero result #{index}",
          result_count: 0,
          request_id: "zero-result-#{index}",
        )
      end

      payload = described_class.call(rows:, period: '24h', view: 'all', now: now)

      expect(payload.fetch('improvement_terms').size).to eq(11)
    end

    it 'builds plain-English summary statuses' do
      expect(payload.fetch('summary_statuses')).to include(
        'failure_rate' => include(
          'level' => 'problem',
          'message' => 'Failures are higher than expected',
        ),
        'p90_latency_ms' => include(
          'level' => 'watch',
          'message' => 'Some searches are taking longer than usual',
        ),
      )
    end

    context 'with the internal view' do
      subject(:payload) do
        described_class.call(
          rows: rows,
          period: '24h',
          view: 'internal',
          now: now,
        )
      end

      it 'maps live interactive telemetry to the dashboard internal view' do
        expect(payload.fetch('summary')).to include(
          'searches' => 2,
          'failure_rate' => 0.5,
          'p90_latency_ms' => 2_000,
        )
      end
    end
  end

  def search_row(timestamp, event, search_type, query, **fields)
    {
      '@timestamp' => timestamp,
      'event' => event,
      'search_type' => search_type,
      'query' => query,
      'results_type' => fields.delete(:results_type) || results_type_for(event, search_type),
      **fields.transform_keys(&:to_s).transform_values { |value| value.is_a?(Hash) ? value.to_json : value.to_s },
    }.compact
  end

  def results_type_for(event, search_type)
    return unless event == 'search_completed'

    search_type == 'classic' ? 'fuzzy_search' : 'hybrid'
  end
end
