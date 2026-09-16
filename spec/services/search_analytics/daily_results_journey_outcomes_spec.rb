RSpec.describe SearchAnalytics::DailyResults do
  let(:date) { Date.new(2026, 9, 14) }
  let(:scope) { { region: 'eu-west-2', log_group_name: 'example-logs', now: Time.utc(2026, 9, 16) } }
  let(:frontend_ids) { (1..13).map { |id| "frontend-#{id}" } }
  let(:admin_ids) { (1..93).map { |id| "admin-#{id}" } }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('No AWS on reads')
    allow(SearchAnalyticsQueryResult).to receive(:fetch).and_raise('No collection on reads')
    store_base(date)
  end

  def fingerprints(day) = SearchAnalytics::DailyQuery.new(reporting_date: day, **scope).fingerprints

  def store(day, name, rows, fingerprint: fingerprints(day).fetch(name))
    SearchAnalyticsQueryResult.create(service: 'uk', reporting_date: day, name:, fingerprint:, rows: Sequel.pg_jsonb(rows), collected_at: scope[:now])
  end

  def store_base(day)
    groups = fingerprints(day).except('frontend_events', 'journey_outcomes').keys.index_with { [] }
    bucket = (day.to_time(:utc) + 8.hours).iso8601
    groups['search_journeys'] = [{ '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'frontend', 'journey_keys' => frontend_ids }]
    groups['volume'] = [
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'frontend', 'event' => 'search_completed', 'searches' => 22 },
      { '@timestamp' => bucket, 'search_type' => 'interactive', 'request_source' => 'backend_only', 'event' => 'search_completed', 'searches' => 93 },
    ]
    groups.each { |name, rows| store(day, name, rows) }
  end

  def outcome_rows
    [
      { 'journey_keys' => frontend_ids.first(11) + admin_ids, 'terminal_state' => 'completed', 'window_end' => '2026-09-14T12:00:00Z', 'questions_seen' => '0', 'unknown_seen' => '0', 'zero_result' => '0', 'selected' => '0' },
      { 'journey_keys' => frontend_ids.last(2), 'terminal_state' => 'none', 'window_end' => '2026-09-14T12:00:00Z', 'questions_seen' => '1', 'unknown_seen' => '0', 'zero_result' => '0', 'selected' => '0' },
    ]
  end

  def read(to: date, view: 'internal')
    range = SearchAnalytics::DateRange.parse(from: date.iso8601, to: to.iso8601, now: scope[:now])
    described_class.call(period: SearchAnalytics::Period.for(period: '7d', view:), date_range: range, **scope)
  end

  it 'reconciles 115 backend completions to 13 frontend journeys without changing legacy request denominators' do
    store(date, 'journey_outcomes', outcome_rows)
    payload = read.payload
    expect(payload['summary']).to include('searches' => 13, 'requests' => 115)
    expect(payload.dig('journeys', 'outcomes')).to include('completed' => 11, 'nonterminal' => 2, 'failed' => 0, 'unknown' => 0)
    expect(payload.dig('trends', 'outcomes').first).to include('completed' => 11, 'nonterminal' => 2)
    expect(payload.dig('journeys', 'outcomes').values_at('completed', 'failed', 'nonterminal', 'unknown').sum).to eq(13)
  end

  it 'includes classification journeys in All without leaking them into Internal outcomes' do
    journeys = SearchAnalyticsQueryResult.where(name: 'search_journeys').first
    journeys.update(rows: Sequel.pg_jsonb(journeys.rows.to_a + [{ '@timestamp' => '2026-09-14T08:00:00Z', 'search_type' => 'classification', 'request_source' => 'frontend', 'journey_keys' => %w[classification-id] }]))
    classified = outcome_rows.first.merge('journey_keys' => %w[classification-id], 'zero_result' => '1')
    store(date, 'journey_outcomes', outcome_rows + [classified])
    expect(read(view: 'all').payload.dig('journeys', 'outcomes')).to include('completed' => 12, 'nonterminal' => 2, 'zero_result' => 1)
    expect(read.payload.dig('journeys', 'outcomes')).to include('completed' => 11, 'nonterminal' => 2, 'zero_result' => 0)
  end

  it 'withholds the old misleading step trend until outcome collection exists' do
    payload = read.payload
    expect(payload['summary']['searches']).to eq(13)
    expect(payload.dig('availability', 'journey_outcomes')).to be(false)
    expect(payload.dig('trends', 'outcomes')).to eq([])
    expect(payload.dig('journeys', 'outcomes')).to be_nil
  end

  it 'does not reuse an incompatible outcome definition' do
    store(date, 'journey_outcomes', outcome_rows, fingerprint: 'old')
    expect(read.payload.dig('availability', 'journey_outcomes')).to be(false)
  end

  it 'requires outcomes for every backend-collected day without hiding other metrics' do
    store(date, 'journey_outcomes', outcome_rows)
    store_base(date + 1)
    payload = read(to: date + 1).payload
    expect(payload.dig('coverage', 'complete')).to be(true)
    expect(payload.dig('availability', 'journey_outcomes')).to be(false)
    expect(payload.dig('availability', 'journey_outcome_coverage', 'missing_dates')).to eq([(date + 1).iso8601])
  end

  it 'serializes only counts, without leaking outcome identifiers' do
    store(date, 'journey_outcomes', outcome_rows)
    json = Api::Admin::SearchAnalyticsSerializer.new(read).serializable_hash.to_json
    expect(json).to include('"nonterminal":2', '"completed":11')
    expect(json).not_to include('frontend-1', 'admin-1', 'journey_keys')
  end
end
