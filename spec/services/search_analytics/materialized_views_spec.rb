# frozen_string_literal: true

RSpec.describe SearchAnalytics::MaterializedViews, :truncation do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:now) { Time.utc(2026, 9, 15, 10) }
  let(:first_date) { Date.new(2026, 9, 13) }
  let(:last_date) { Date.new(2026, 9, 14) }
  let(:region) { 'eu-west-2' }
  let(:log_group_name) { 'example-logs' }
  let(:scope) { { region:, log_group_name:, now: } }
  let(:shared_key) { Digest::SHA256.hexdigest('shared') }
  let(:first_key) { Digest::SHA256.hexdigest('first') }
  let(:last_key) { Digest::SHA256.hexdigest('last') }
  let(:db) { SearchAnalyticsQueryResult.db }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('Refresh must not construct an AWS client')
    allow(SearchAnalytics::DailyQuery).to receive(:call).and_raise('Refresh must not collect results')
    described_class.refresh!(concurrently: false, force: true) if described_class.ready?
  end

  after do
    next unless described_class.ready?

    SearchAnalyticsQueryResult.where(name: described_class::SOURCE_NAMES).delete
    described_class.refresh!(concurrently: false, force: true)
  end

  def refresh!(**extra) = described_class.refresh!(**extra)

  def definitions(date = last_date, service: TradeTariffBackend.service)
    previous = TradeTariffBackend.service
    allow(TradeTariffBackend).to receive(:service).and_return(service)
    SearchAnalytics::DailyQuery.new(reporting_date: date, **scope).fingerprints
  ensure
    allow(TradeTariffBackend).to receive(:service).and_return(previous)
  end

  def store(date, name, rows, service: 'uk', fingerprint: definitions(date, service:).fetch(name), collected_at: now - 1.hour)
    SearchAnalyticsQueryResult.create(
      service:, reporting_date: date, name:, fingerprint:,
      rows: Sequel.pg_jsonb(rows), collected_at:
    )
  end

  def journey_row(key, time, search_type: 'classic')
    { '@timestamp' => time.iso8601, 'search_type' => search_type, 'request_source' => 'frontend', 'journey_keys' => [key] }
  end

  def outcome_row(key, time, terminal_state: 'completed', selected: 1, zero_result: 0)
    {
      'terminal_state' => terminal_state,
      'window_end' => time.iso8601,
      'selected' => selected,
      'zero_result' => zero_result,
      'questions_seen' => 0,
      'unknown_seen' => 0,
      'journey_keys' => [key],
    }
  end

  def store_day(date, keys:, service: 'uk')
    time = date.to_time(:utc) + 8.hours
    store(date, 'search_journeys', keys.map { |key| journey_row(key, time) }, service:)
    store(date, 'journey_outcomes', keys.map { |key| outcome_row(key, time) }, service:)
    store(date, 'volume', [{ 'searches' => 1 }], service:)
  end

  def hex_keys(model = SearchAnalytics::DailyJourney, service: 'uk')
    model = described_class::MODELS.find { |entry| entry.table_name.to_sym == model } if model.is_a?(Symbol)
    model.where(service:).select_map(:journey_key).map { |key| key.unpack1('H*') }.sort
  end

  def source_records(service: 'uk')
    SearchAnalyticsQueryResult
      .where(service:, name: described_class::SOURCE_NAMES)
      .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at)
      .all
  end

  it 'normalises matching fingerprints and rolls up single-day identities' do
    store_day(first_date, keys: [first_key])
    store_day(last_date, keys: [last_key])

    expect(refresh!).to be(true)
    expect(described_class.ready?).to be(true)
    expect(SearchAnalytics::SourceRevision.select_map(:definition_version).uniq).to eq([described_class::VERSION])
    expect(hex_keys(:search_analytics_daily_journeys)).to eq([first_key, last_key].sort)
    expect(hex_keys(:search_analytics_repeated_journeys)).to eq([])
    expect(SearchAnalytics::JourneyRollupTotal.where(view: 'all', bucket_size: 'day').select_map(:journeys).sum).to eq(2)
  end

  it 'rebuilds after force replacement, deletion, a new selected date and a multi-day promotion' do
    store_day(first_date, keys: [shared_key])
    refresh!
    expect(SearchAnalytics::JourneyRollupTotal.where(view: 'all', bucket_size: 'day').get(:journeys)).to eq(1)
    expect(SearchAnalytics::RepeatedJourney.count).to eq(0)

    SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'search_journeys')
      .update(collected_at: now, rows: Sequel.pg_jsonb([journey_row(shared_key, first_date.to_time(:utc) + 9.hours)]))
    expect(refresh!).to be(true)
    expect(SearchAnalytics::DailyJourney.get(:all_hours)).to eq(1 << 9)

    SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'journey_outcomes').delete
    expect(refresh!).to be(true)
    expect(SearchAnalytics::DailyJourney.count).to eq(1)
    expect(SearchAnalytics::DailyJourney.get(:terminal)).to be_nil

    store_day(last_date, keys: [shared_key])
    expect(refresh!).to be(true)
    expect(hex_keys(:search_analytics_repeated_journeys).uniq).to eq([shared_key])
    expect(SearchAnalytics::JourneyRollupTotal.where(view: 'all', bucket_size: 'day').select_map(:journeys).sum).to eq(0)
  end

  it 'skips a rebuild when populated source revisions already match live source metadata' do
    store_day(first_date, keys: [first_key])
    store_day(last_date, keys: [last_key])
    refresh!
    store(last_date - 2, 'volume', [{ 'searches' => 1 }])

    expect(refresh!).to be(false)
  end

  it 'rebuilds when force is true even if source revisions match' do
    store_day(last_date, keys: [last_key])
    refresh!
    expect(refresh!).to be(false)
    expect(refresh!(force: true)).to be(true)
  end

  it 'does not apply privileged rebuild settings when the generation is unchanged' do
    store_day(last_date, keys: [last_key])
    refresh!
    refresher = described_class.new
    expect(refresher).not_to receive(:apply_local_settings)
    expect(refresher.refresh!).to be(false)
  end

  it 'does not mix UK and XI identities and keeps both services in the current schema' do
    store_day(last_date, keys: [first_key], service: 'uk')
    store_day(last_date, keys: [last_key], service: 'xi')
    refresh!

    expect(hex_keys(:search_analytics_daily_journeys, service: 'uk')).to eq([first_key])
    expect(hex_keys(:search_analytics_daily_journeys, service: 'xi')).to eq([last_key])

    expect(refresh!).to be(false)
    expect(SearchAnalytics::SourceRevision.select_map(:service).uniq.sort).to eq(%w[uk xi])
  end

  it 'rolls back a failed blocking rebuild and keeps the previous snapshot' do
    store_day(first_date, keys: [first_key])
    refresh!
    store(last_date, 'search_journeys', [journey_row('not-hex', last_date.to_time(:utc) + 8.hours)])

    expect { refresh!(concurrently: false) }.to raise_error(Sequel::DatabaseError)
    expect(hex_keys(:search_analytics_daily_journeys)).to eq([first_key])
    expect(SearchAnalytics::SourceRevision.select_map(:reporting_date).uniq).to eq([first_date])
  end

  it 'rolls back a failed concurrent rebuild and keeps the previous snapshot' do
    store_day(first_date, keys: [first_key])
    refresh!
    store(last_date, 'search_journeys', [journey_row('not-hex', last_date.to_time(:utc) + 8.hours)])

    expect { refresh!(concurrently: true) }.to raise_error(Sequel::DatabaseError)
    expect(hex_keys(:search_analytics_daily_journeys)).to eq([first_key])
    expect(SearchAnalytics::SourceRevision.select_map(:reporting_date).uniq).to eq([first_date])
  end

  it 'treats empty successful sources as present and ignores non-source query slots' do
    store(last_date, 'search_journeys', [])
    store(last_date, 'journey_outcomes', [])
    store(last_date, 'volume', [{ 'searches' => 1 }])
    refresh!

    expect(SearchAnalytics::DailyJourney.count).to eq(0)
    expect(SearchAnalytics::SourceRevision.select_map(:name).sort).to eq(%w[journey_outcomes search_journeys])
  end

  it 'materialises stale outcome definitions without making current journey fingerprints incompatible' do
    store_day(last_date, keys: [last_key])
    SearchAnalyticsQueryResult.where(name: 'journey_outcomes').update(fingerprint: 'obsolete')
    refresh!

    records = source_records
    current = definitions
    expect(described_class.compatible?(records:, definitions: current, dates: [last_date], service: 'uk')).to be(true)
    expect(hex_keys(:search_analytics_daily_journeys)).to eq([last_key])
  end

  it 'rejects a nested call so the rebuild owns its transaction' do
    db.transaction do
      expect { refresh! }.to raise_error(ArgumentError, /own its repeatable-read transaction/)
    end
  end

  it 'does not wait for the advisory lock by default' do
    allow(db).to receive(:with_advisory_lock).and_call_original
    store_day(last_date, keys: [last_key])
    refresh!
    expect(db).to have_received(:with_advisory_lock).with(kind_of(Integer), wait: false)
  end

  it 'skips unpopulated views after the lock' do
    refresher = described_class.new
    lock_id = refresher.send(:lock_id)
    checker = postgres_connection
    allow(refresher).to receive(:populated?) do
      expect(checker.exec_params('SELECT pg_try_advisory_lock($1)', [lock_id]).getvalue(0, 0)).to eq('f')
      false
    end
    allow(refresher).to receive(:apply_local_settings)
    allow(refresher).to receive(:refresh_matviews)

    expect(refresher.refresh!(only_if_populated: true)).to be(false)
    expect(refresher).not_to have_received(:apply_local_settings)
    expect(refresher).not_to have_received(:refresh_matviews)
  ensure
    checker&.close
  end

  it 'raises while the refresh lock is held' do
    refresher = described_class.new
    lock_id = refresher.send(:lock_id)
    holder = postgres_connection
    holder.exec_params('SELECT pg_advisory_lock($1)', [lock_id])
    allow(refresher).to receive(:populated?).and_return(false)

    expect { refresher.refresh!(only_if_populated: true, wait: false) }.to raise_error(Sequel::AdvisoryLockError)
    expect(refresher).not_to have_received(:populated?)
  ensure
    holder&.exec_params('SELECT pg_advisory_unlock($1)', [lock_id]) if lock_id
    holder&.close
  end

  it 'rebuilds populated views when asked' do
    store_day(last_date, keys: [last_key])
    expect(refresh!(only_if_populated: true)).to be(true)
  end

  it 'uses a blocking fill when views are not populated' do
    store_day(last_date, keys: [last_key])
    refresher = described_class.new
    allow(refresher).to receive(:populated?).and_return(false)
    allow(refresher).to receive(:refresh_matviews).and_call_original
    expect(refresher.refresh!(concurrently: true)).to be(true)
    expect(refresher).to have_received(:refresh_matviews).with(concurrently: false)
  end

  it 'refreshes concurrently after the initial population' do
    store_day(last_date, keys: [last_key])
    statements = []
    allow(db).to receive(:run).and_wrap_original do |original, sql|
      statements << sql
      original.call(sql)
    end
    refresh!
    expect(statements.grep(/REFRESH MATERIALIZED VIEW CONCURRENTLY/)).to eq(
      described_class::MATVIEWS.map { |name| "REFRESH MATERIALIZED VIEW CONCURRENTLY #{name}" },
    )
  end

  it 'keeps concurrent refresh inside the repeatable-read transaction' do
    store_day(last_date, keys: [last_key])
    refresher = described_class.new
    allow(refresher).to receive(:refresh_matviews).and_wrap_original do |original, concurrently:|
      expect(db.in_transaction?).to be(true)
      original.call(concurrently:)
    end
    expect(refresher.refresh!(concurrently: true)).to be(true)
  end

  it 'restores session settings after a committed rebuild' do
    store_day(last_date, keys: [last_key])
    db.synchronize do
      settings = session_settings
      begin
        db.run("SET work_mem = '8MB'")
        refresh!(concurrently: false)
        expect(session_settings).to eq(settings.merge('work_mem' => '8MB'))
      ensure
        db.run("SET work_mem = #{db.literal(settings.fetch('work_mem'))}")
      end
      expect(session_settings).to eq(settings)
    end
  end

  it 'treats populated empty views as ready and compatible' do
    expect(described_class.ready?).to be(true)
    expect(described_class.compatible?(records: [], definitions: definitions, dates: [last_date], service: 'uk')).to be(true)
  end

  def session_settings
    {
      'TimeZone' => db.get { current_setting('TimeZone') },
      'work_mem' => db.get { current_setting('work_mem') },
      'temp_file_limit' => db.get { current_setting('temp_file_limit') },
      'statement_timeout' => db.get { current_setting('statement_timeout') },
    }
  end

  def postgres_connection
    opts = db.opts
    PG.connect(
      host: opts[:host],
      port: opts[:port],
      dbname: opts[:database],
      user: opts[:user],
      password: opts[:password],
    )
  end
end
