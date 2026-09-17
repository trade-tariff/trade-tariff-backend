# frozen_string_literal: true

RSpec.describe SearchAnalytics::ReadModelRefresh, :truncation do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:now) { Time.utc(2026, 9, 15, 10) }
  let(:first_date) { Date.new(2026, 9, 13) }
  let(:last_date) { Date.new(2026, 9, 14) }
  let(:region) { 'eu-west-2' }
  let(:log_group_name) { 'example-logs' }
  let(:scope) { { region:, log_group_name:, now: } }
  let(:shared_key) { Digest::SHA256.hexdigest('shared') }
  let(:first_key) { Digest::SHA256.hexdigest('first') }
  let(:last_key) { Digest::SHA256.hexdigest('last') }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('Refresh must not construct an AWS client')
    allow(SearchAnalytics::DailyQuery).to receive(:call).and_raise('Refresh must not collect results')
  end

  def rebuild(**extra)
    described_class.call(**scope.except(:log_group_name).merge(log_group_name:).merge(extra))
  end

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

  def hex_keys(model, dataset)
    model.public_send(dataset).select_map(:journey_key).map { |key| key.unpack1('H*') }.sort
  end

  it 'normalises matching fingerprints and rolls up single-day identities' do
    store_day(first_date, keys: [first_key])
    store_day(last_date, keys: [last_key])

    model = rebuild(from: first_date, to: last_date)

    expect(model.version).to eq(SearchAnalyticsReadModel::VERSION)
    expect(hex_keys(model, :journey_days_dataset)).to eq([first_key, last_key].sort)
    expect(hex_keys(model, :multi_day_observations_dataset)).to eq([])
    expect(model.journey_rollups_dataset.where(view: 'all', bucket_size: 'day').select_map(:journeys).sum).to eq(2)
  end

  it 'rebuilds after force replacement, deletion, a new selected date and a multi-day promotion' do
    store_day(first_date, keys: [shared_key])
    first = rebuild(from: first_date, to: first_date)
    expect(first.journey_rollups_dataset.where(view: 'all', bucket_size: 'day').get(:journeys)).to eq(1)
    expect(first.multi_day_observations_dataset.count).to eq(0)

    SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'search_journeys')
      .update(collected_at: now, rows: Sequel.pg_jsonb([journey_row(shared_key, first_date.to_time(:utc) + 9.hours)]))
    replaced = rebuild(from: first_date, to: first_date)
    expect(replaced.id).not_to eq(first.id)
    expect(SearchAnalyticsReadModel.where(service: 'uk', region:).select_map(:id)).to eq([replaced.id])

    SearchAnalyticsQueryResult.where(reporting_date: first_date, name: 'journey_outcomes').delete
    deleted = rebuild(from: first_date, to: first_date)
    expect(deleted.id).not_to eq(replaced.id)
    expect(deleted.journey_days_dataset.count).to eq(1)

    store_day(last_date, keys: [shared_key])
    promoted = rebuild(from: first_date, to: last_date)
    expect(hex_keys(promoted, :multi_day_observations_dataset).uniq).to eq([shared_key])
    expect(promoted.journey_rollups_dataset.where(view: 'all', bucket_size: 'day').select_map(:journeys).sum).to eq(0)
  end

  it 'skips a rebuild when the latest generation already covers the selected source rows' do
    store_day(first_date, keys: [first_key])
    store_day(last_date, keys: [last_key])
    model = rebuild(from: first_date, to: last_date)
    store_day(last_date - 2, keys: [Digest::SHA256.hexdigest('outside')])

    expect(rebuild(from: first_date, to: last_date).id).to eq(model.id)
  end

  it 'does not apply privileged rebuild settings when the generation is unchanged' do
    store_day(last_date, keys: [last_key])
    model = rebuild(from: last_date, to: last_date)
    refresher = described_class.new(**scope, from: last_date, to: last_date)
    expect(refresher).not_to receive(:apply_local_settings)
    expect(refresher.call.id).to eq(model.id)
  end

  it 'refuses to replace a wider generation with a changed narrower range' do
    store_day(first_date, keys: [first_key])
    store_day(last_date, keys: [last_key])
    model = rebuild(from: first_date, to: last_date)
    expect(rebuild(from: last_date, to: last_date).id).to eq(model.id)
    SearchAnalyticsQueryResult.where(reporting_date: last_date, name: 'search_journeys').update(collected_at: now + 1)
    expect { rebuild(from: last_date, to: last_date) }.to raise_error(SearchAnalytics::DateRange::InvalidRange, /existing read-model dates/)
    expect(SearchAnalyticsReadModel.latest(service: 'uk', region:).id).to eq(model.id)
    expect(model.journey_days_dataset.select_map(:reporting_date).uniq.sort).to eq([first_date, last_date])
    expect(rebuild.id).not_to eq(model.id)
  end

  it 'does not mix UK and XI generations and does not prune the other service' do
    store_day(last_date, keys: [first_key], service: 'uk')
    uk_model = rebuild(from: last_date, to: last_date)
    store_day(last_date, keys: [last_key], service: 'xi')
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
    xi_model = rebuild(from: last_date, to: last_date)

    expect(uk_model.service).to eq('uk')
    expect(xi_model.service).to eq('xi')
    expect(hex_keys(uk_model, :journey_days_dataset)).to eq([first_key])
    expect(hex_keys(xi_model, :journey_days_dataset)).to eq([last_key])

    allow(TradeTariffBackend).to receive(:service).and_return('uk')
    rebuilt = rebuild(from: last_date, to: last_date)
    expect(rebuilt.id).to eq(uk_model.id)
    expect(SearchAnalyticsReadModel.latest(service: 'xi', region:).id).to eq(xi_model.id)
  end

  it 'rolls back a failed rebuild and keeps the previous generation' do
    store_day(first_date, keys: [first_key])
    model = rebuild(from: first_date, to: first_date)
    store(last_date, 'search_journeys', [journey_row('not-hex', last_date.to_time(:utc) + 8.hours)])

    expect { rebuild(from: first_date, to: last_date) }.to raise_error(Sequel::DatabaseError)
    expect(SearchAnalyticsReadModel.latest(service: 'uk', region:).id).to eq(model.id)
    expect(hex_keys(model, :journey_days_dataset)).to eq([first_key])
  end

  it 'defaults to the last 366 completed UTC days and rejects invalid ranges' do
    excluded = last_date - SearchAnalytics::DateRange::MAX_DAYS
    store_day(excluded, keys: [Digest::SHA256.hexdigest('too-old')])
    store_day(last_date, keys: [last_key])

    model = rebuild
    expect(hex_keys(model, :journey_days_dataset)).to eq([last_key])
    expect { rebuild(from: last_date) }.to raise_error(SearchAnalytics::DateRange::InvalidRange)
    expect { rebuild(from: last_date, to: last_date + 1) }.to raise_error(SearchAnalytics::DateRange::InvalidRange)
    expect { rebuild(from: last_date, to: first_date) }.to raise_error(SearchAnalytics::DateRange::InvalidRange)
    expect { described_class.call(region: '') }.to raise_error(ArgumentError, /Region/)
  end

  it 'rejects a nested call so the rebuild owns its transaction' do
    SearchAnalyticsReadModel.db.transaction do
      expect { rebuild(from: last_date, to: last_date) }.to raise_error(ArgumentError, /own its repeatable-read transaction/)
    end
  end

  it 'restores session settings after a committed rebuild' do
    store_day(last_date, keys: [last_key])
    db = SearchAnalyticsReadModel.db
    db.synchronize do
      settings = session_settings
      begin
        db.run("SET work_mem = '8MB'")
        rebuild(from: last_date, to: last_date)
        expect(session_settings).to eq(settings.merge('work_mem' => '8MB'))
      ensure
        db.run("SET work_mem = #{db.literal(settings.fetch('work_mem'))}")
      end
      expect(session_settings).to eq(settings)
    end
  end

  def session_settings
    db = SearchAnalyticsReadModel.db
    {
      'TimeZone' => db.get { current_setting('TimeZone') },
      'work_mem' => db.get { current_setting('work_mem') },
      'temp_file_limit' => db.get { current_setting('temp_file_limit') },
      'statement_timeout' => db.get { current_setting('statement_timeout') },
    }
  end
end
