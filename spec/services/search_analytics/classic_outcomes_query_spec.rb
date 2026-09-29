RSpec.describe SearchAnalytics::ClassicOutcomesQuery do
  subject(:sql) { described_class.call(source: '`example-logs`', log_stream_filter: 'streams') }

  it 'counts frontend classic fuzzy completions by total result count' do
    expect(sql).to include("search_type = 'classic'", "results_type = 'fuzzy_search'", "request_source = 'frontend'", 'result_count >= 0', 'event_count')
    expect(sql).not_to include('commodity_result_count', 'zero_result', 'exact_search', 'exact_match', 'heading_result_count', 'search_degraded')
  end

  it 'stores two daily counts and keeps the latest completion' do
    rows = described_class.collapse([
      { 'journey_key' => 'a', 'result_count' => '0', 'observed_at' => '2026-09-28T09:00:00Z' },
      { 'journey_key' => 'a', 'result_count' => '3', 'observed_at' => '2026-09-28T10:00:00Z' },
      { 'journey_key' => 'b', 'result_count' => '0', 'observed_at' => '2026-09-28T11:00:00Z' },
    ])

    expect(rows).to eq([
      { 'outcome' => 'results', 'searches' => 1, 'event_count' => 1 },
      { 'outcome' => 'no_results', 'searches' => 1, 'event_count' => 1 },
    ])
    expect(rows.to_json).not_to include('journey_key')
  end

  it 'stores nothing when the day has no classic completions' do
    expect(described_class.collapse([])).to eq([])
  end
end
