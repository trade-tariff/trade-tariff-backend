RSpec.describe SearchAnalytics::DailyResults do
  let(:date) { Date.new(2026, 9, 14) }
  let(:now) { Time.utc(2026, 9, 16) }
  let(:scope) { { region: 'eu-west-2', log_group_name: 'example-logs', now: } }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('No AWS reads')
    allow(SearchAnalyticsQueryResult).to receive(:fetch).and_raise('No collection on reads')
    store_backend(date)
  end

  def definitions(day) = SearchAnalytics::DailyQuery.new(reporting_date: day, **scope).fingerprints

  def store_backend(day)
    definitions(day).except('frontend_events').each { |name, fingerprint| store(day, name, [], fingerprint) }
  end

  def store(day, name, rows, fingerprint = definitions(day).fetch(name))
    SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: day, name:, fingerprint:, rows: Sequel.pg_jsonb(rows), collected_at: now)
  end

  def frontend_row
    { 'journey_key' => 'hashed-id', 'outcome' => 'results', 'event_count' => '1', 'reported_questions' => '2', 'navigation_observations' => '0', 'navigation_total_ms' => '0' }
  end

  def read(view: 'internal', to: date)
    range = SearchAnalytics::DateRange.parse(from: date.iso8601, to: to.iso8601, now:)
    described_class.call(period: SearchAnalytics::Period.for(period: '7d', view:), date_range: range, **scope)
  end

  it 'keeps the existing eight-group dashboard available before frontend collection' do
    result = read
    expect(result.payload.dig('coverage', 'complete')).to be(true)
    expect(result.payload.dig('frontend_events', 'available')).to be(false)
    expect(result.payload.dig('frontend_events', 'coverage', 'missing_dates')).to eq([date.iso8601])
  end

  it 'reads compatible frontend data and serializes only aggregate fields' do
    store(date, 'frontend_events', [frontend_row])
    result = read
    payload = Api::Admin::SearchAnalyticsSerializer.new(result).serializable_hash[:data][:attributes][:frontend_events]
    expect(payload).to include('available' => true, 'observed_journeys' => 1)
    expect(payload.dig('coverage', 'complete')).to be(true)
    expect(payload.to_json).not_to include('hashed-id', 'journey_key')
  end

  it 'shows unavailable rather than zero when the frontend definition is stale' do
    store(date, 'frontend_events', [frontend_row], 'old-definition')
    expect(read.payload.dig('frontend_events', 'available')).to be(false)
    expect(read.payload.dig('coverage', 'complete')).to be(true)
  end

  it 'keeps frontend coverage independent from complete backend coverage' do
    store_backend(date + 1)
    store(date, 'frontend_events', [frontend_row])
    payload = read(to: date + 1).payload
    expect(payload.dig('coverage', 'complete')).to be(true)
    expect(payload.dig('frontend_events', 'coverage')).to include('collected_days' => 1, 'expected_days' => 2, 'complete' => false)
  end

  it 'excludes frontend rows for dates without complete backend groups' do
    store(date + 1, 'frontend_events', [frontend_row])
    expect(read(to: date + 1).payload.dig('frontend_events', 'available')).to be(false)
  end

  it 'does not expose guided events on the Classic view' do
    store(date, 'frontend_events', [frontend_row])
    expect(read(view: 'classic').payload.dig('frontend_events', 'coverage', 'supported')).to be(false)
    expect(read(view: 'all').payload.dig('frontend_events', 'available')).to be(true)
  end

  it 'does not treat UK frontend events as XI data' do
    store(date, 'frontend_events', [frontend_row])
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    store_backend(date)
    expect(read.payload.dig('coverage', 'complete')).to be(true)
    expect(read.payload.dig('frontend_events', 'coverage', 'supported')).to be(false)
  end

  it 'treats a successful empty frontend group as available, not missing' do
    store(date, 'frontend_events', [])
    expect(read.payload['frontend_events']).to include('available' => true, 'observed_journeys' => 0)
  end
end
