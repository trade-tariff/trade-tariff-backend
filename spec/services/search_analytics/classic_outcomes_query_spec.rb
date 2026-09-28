RSpec.describe SearchAnalytics::ClassicOutcomesQuery do
  subject(:sql) { described_class.call(source: '`example-logs`', log_stream_filter: 'streams') }

  it 'counts frontend classic fuzzy completions by total result count' do
    expect(sql).to include("search_type = 'classic'", "results_type = 'fuzzy_search'", "request_source = 'frontend'", 'result_count >= 0', 'event_count')
    expect(sql).not_to include('commodity_result_count', 'zero_result', 'exact_search', 'exact_match', 'heading_result_count', 'search_degraded')
  end
end
