RSpec.describe SearchAnalytics::DailyResults do
  let(:now) { Time.utc(2026, 9, 15, 10) }
  let(:first_date) { Date.new(2026, 9, 13) }
  let(:last_date) { Date.new(2026, 9, 14) }
  let(:scope) { { region: 'eu-west-2', log_group_name: 'example-logs', now: } }

  before do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('Reader must not construct an AWS client')
    allow(SearchAnalytics::DailyQuery).to receive(:call).and_raise('Reader must not collect results')
    allow(SearchAnalyticsQueryResult).to receive(:fetch).and_raise('Reader must not execute or write queries')
    create_day(first_date, completed: 8, failed: 2, zero: 2, selected: 3, eligible: 4)
    create_day(last_date, completed: 90, failed: 0, zero: 1, selected: 1, eligible: 40)
  end

  def read(view = 'internal', period = '30d', **extra)
    described_class.call(period: SearchAnalytics::Period.for(view:, period:), **scope, **extra)
  end

  def measurements(date, completed:, failed:, zero:, selected:, eligible:)
    bucket = (date.to_time(:utc) + 8.hours).iso8601
    rows = SearchAnalytics::DailyQuery.new(reporting_date: date, **scope).query_definitions.keys.index_with { [] }
    rows['volume'] = [
      { '@timestamp' => bucket, 'search_type' => 'classic', 'event' => 'search_completed', 'searches' => completed, 'zero_results' => zero },
      { '@timestamp' => bucket, 'search_type' => 'classic', 'event' => 'search_failed', 'searches' => failed, 'zero_results' => 0 },
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'event' => 'search_completed', 'searches' => 3, 'zero_results' => 0 },
    ]
    rows['search_journeys'] = [
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'frontend', 'journey_keys' => %w[shared] },
      { '@timestamp' => bucket, 'search_type' => 'classic', 'request_source' => 'frontend', 'journey_keys' => [date.iso8601] },
    ]
    rows['latency_histogram'] = [{ 'search_type' => 'classic', 'latency_bucket' => SearchAnalytics::LatencyHistogram.bucket(1000), 'observations' => completed + failed }]
    rows['classic_selection_trend'] = [{ '@timestamp' => bucket, 'selected' => selected, 'selectable' => eligible }]
    rows['search_term_improvements'] = [{ 'query' => 'trainers', 'search_type' => 'classic', 'zero_results' => zero }]
    rows['ai_cost_summary'] = [{ 'journey_key' => 'shared', 'total_cost_usd' => '0.03', 'priced_calls' => '2', 'unpriced_calls' => '1' }]
    rows['ai_cost_trend'] = [{ '@timestamp' => bucket, 'journey_key' => 'shared', 'event_kind' => 'interactive_search', 'total_cost_usd' => '0.03', 'calls' => '3', 'priced_calls' => '2', 'unpriced_calls' => '1' }]
    rows
  end

  def create_day(date, **counts)
    definitions = SearchAnalytics::DailyQuery.new(reporting_date: date, **scope).fingerprints
    measurements(date, **counts).each do |name, rows|
      SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: date, name:, fingerprint: definitions.fetch(name), rows: Sequel.pg_jsonb(rows), collected_at: now - 1.hour)
    end
  end

  def replace_rows(date, name, rows)
    SearchAnalyticsQueryResult.where(reporting_date: date, name:).update(rows: Sequel.pg_jsonb(rows))
  end

  it 'deduplicates the same frontend journey across days without collapsing its AI calls' do
    payload = read.payload
    expect(payload['summary']).to include('searches' => 1, 'requests' => 6)
    expect(payload.dig('ai_costs', 'summary')).to include('total_cost_usd' => 0.06, 'priced_calls' => 4, 'unpriced_calls' => 2, 'complete' => false)
    expect(payload.dig('ai_costs', 'operations').first['calls']).to eq(6)
    expect(payload.dig('trends', 'volume').map { |row| row['internal'] }).to eq([1, 1])
  end

  it 'derives existing rates from their summed request denominators, not the journey headline' do
    payload = read('classic').payload
    expect(payload['summary']).to include('searches' => 2, 'requests' => 100, 'failure_rate' => 0.02, 'zero_result_rate' => 3.0 / 98, 'selection_rate' => 4.0 / 44)
    expect(payload['improvement_terms']).to include('query' => 'trainers', 'term_type' => 'search_terms', 'zero_results' => 3)
  end

  it 'reports missing days instead of inventing zero traffic' do
    snapshot = read
    expect(snapshot.payload['coverage']).to include('expected_days' => 30, 'collected_days' => 2, 'complete' => false)
    expect(snapshot.payload.dig('coverage', 'missing_dates').size).to eq(28)
    expect(snapshot.generated_at).to eq(now - 1.hour)
    expect(snapshot.data_through).to eq(Time.utc(2026, 9, 15))
  end

  it 'excludes a whole incomplete day until its missing query succeeds' do
    SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'latency_histogram').delete
    expect(read.payload['coverage']).to include('collected_days' => 1, 'collected_dates' => [last_date.iso8601])
    expect(read.payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(0.03)
  end

  it 'excludes stale definitions rather than mixing query semantics' do
    SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'search_journeys').update(fingerprint: 'obsolete')
    expect(read.payload.dig('coverage', 'collected_dates')).to eq([last_date.iso8601])
  end

  it 'does not substitute another region, log group or service' do
    expect(read(region: 'eu-west-1')).to be_nil
    expect(read(log_group_name: 'different-logs')).to be_nil
    other_service = TradeTariffBackend.service == 'uk' ? 'xi' : 'uk'
    allow(TradeTariffBackend).to receive(:service).and_return(other_service)
    expect(read).to be_nil
  end

  it 'does not fall back to older dates when yesterday is absent' do
    SearchAnalyticsQueryResult.where(reporting_date: last_date).delete
    expect(read('internal', '24h')).to be_nil
  end

  it 'retains hourly bins for one day and daily bins for a longer range' do
    expect(read('internal', '24h').payload.dig('trends', 'volume').first['bucket']).to eq('2026-09-14T08:00:00Z')
    expect(read.payload.dig('trends', 'volume').first['bucket']).to eq('2026-09-13T00:00:00Z')
  end

  it 'uses inclusive custom dates without reading outside that range' do
    range = SearchAnalytics::DateRange.parse(from: first_date.iso8601, to: first_date.iso8601, now:)
    snapshot = read(date_range: range)
    expect(snapshot.period).to eq('custom')
    expect(snapshot.bucket_size).to eq('hour')
    expect(snapshot.payload['coverage']).to include('complete' => true, 'collected_dates' => [first_date.iso8601])
  end

  it 'derives approximate P90 from all observations rather than averaging daily P90s' do
    replace_rows(first_date, 'latency_histogram', [{ 'search_type' => 'classic', 'latency_bucket' => SearchAnalytics::LatencyHistogram.bucket(1000), 'observations' => 10 }])
    replace_rows(last_date, 'latency_histogram', [{ 'search_type' => 'classic', 'latency_bucket' => SearchAnalytics::LatencyHistogram.bucket(10), 'observations' => 90 }])
    payload = read('classic').payload
    expect(payload.dig('summary', 'p90_latency_ms')).to be_between(10, 10.5)
    expect(payload.dig('availability', 'latency_percentiles_approximate')).to be(true)
    expect(payload.dig('request_sources', 'frontend', 'p90_latency_ms')).to be_nil
  end

  it 'returns neutral unavailable latency rather than zero for missing observations' do
    payload = read.payload
    expect(payload.dig('summary', 'p90_latency_ms')).to be_nil
    expect(payload.dig('summary_statuses', 'p90_latency_ms', 'level')).to eq('neutral')
  end

  it 'excludes a day with inconsistent cost results while other complete days remain readable' do
    original = SearchAnalyticsQueryResult.where(reporting_date: last_date, name: 'ai_cost_trend').first.rows.to_a
    replace_rows(last_date, 'ai_cost_trend', [])
    expect(read.payload['coverage']).to include('collected_days' => 1, 'collected_dates' => [first_date.iso8601])
    expect(read('internal', '24h')).to be_nil
    replace_rows(last_date, 'ai_cost_trend', original)
    expect(read.payload['coverage']).to include('collected_days' => 2)
  end

  it 'keeps All and per-view frontend populations distinct' do
    expect(read('all').payload.dig('summary', 'searches')).to eq(3)
    expect(read('classic').payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(0)
    expect(read('all').payload.dig('comparisons', 'internal', 'searches')).to eq(1)
  end

  it 'sums complete term counts before applying the per-category presentation limit' do
    [first_date, last_date].each do |date|
      terms = Array.new(150) { |index| { 'query' => "#{date}-term-#{index}", 'search_type' => 'classic', 'zero_results' => 5 } }
      terms << { 'query' => 'persistent', 'search_type' => 'classic', 'zero_results' => 4 }
      replace_rows(date, 'search_term_improvements', terms)
      replace_rows(date, 'item_id_improvements', [{ 'query' => '0101210000', 'search_type' => 'classic', 'zero_results' => 2 }])
    end
    terms = read('classic').payload['improvement_terms']
    expect(terms.count { |row| row['term_type'] == 'search_terms' }).to eq(100)
    expect(terms).to include('query' => 'persistent', 'term_type' => 'search_terms', 'zero_results' => 8)
    expect(terms).to include('query' => '0101210000', 'term_type' => 'item_ids', 'zero_results' => 4)
  end

  it 'joins costs across midnight only when the frontend start is in the selected range' do
    replace_rows(last_date, 'search_journeys', [])
    expect(read.payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(0.06)
    expect(read('internal', '24h').payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(0)
    expect(read('internal', '24h').payload.dig('summary', 'searches')).to eq(0)
  end

  it 'retains a collected request bucket as zero journeys when no frontend start exists' do
    replace_rows(last_date, 'search_journeys', [])
    volume = read.payload.dig('trends', 'volume')
    expect(volume.map { |row| row['bucket'] }).to eq(%w[2026-09-13T00:00:00Z 2026-09-14T00:00:00Z])
    expect(volume.map { |row| row['internal'] }).to eq([1, 0])
    expect(volume.map { |row| row['unknown'] }).to eq([13, 93])
  end

  it 'retains journey-only buckets without inventing request outcomes' do
    replace_rows(last_date, 'search_journeys', [{ '@timestamp' => '2026-09-14T09:00:00Z', 'search_type' => 'interactive', 'request_source' => 'frontend', 'journey_keys' => %w[only-started] }])
    payload = read('internal', '24h').payload
    expect(payload.dig('trends', 'volume').map { |row| row['bucket'] }).to eq(%w[2026-09-14T08:00:00Z 2026-09-14T09:00:00Z])
    expect(payload.dig('trends', 'volume').map { |row| row['internal'] }).to eq([0, 1])
    expect(payload.dig('trends', 'outcomes').size).to eq(1)
    expect(payload.dig('trends', 'volume').last).to include('frontend' => 0, 'admin' => 0, 'mcp' => 0, 'backend_only' => 0, 'unknown' => 0)
  end

  it 'does not include later calls for the same journey outside the selected dates' do
    range = SearchAnalytics::DateRange.parse(from: first_date.iso8601, to: first_date.iso8601, now:)
    payload = read(date_range: range).payload
    expect(payload.dig('ai_costs', 'summary', 'total_cost_usd')).to eq(0.03)
    expect(payload.dig('ai_costs', 'operations').first['calls']).to eq(3)
  end

  it 'does not mutate stored hourly rows when rendering a daily range' do
    before = SearchAnalyticsQueryResult.where(name: 'ai_cost_trend').all.map { |row| row.rows.to_a }
    read
    expect(SearchAnalyticsQueryResult.where(name: 'ai_cost_trend').all.map { |row| row.rows.to_a }).to eq(before)
  end

  it 'returns nothing when no complete stored day exists' do
    SearchAnalyticsQueryResult.dataset.delete
    expect(read).to be_nil
  end
end
