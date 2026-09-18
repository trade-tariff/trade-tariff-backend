RSpec.describe SearchAnalyticsQueryWorker, type: :worker do
  let(:date) { Date.new(2026, 9, 14) }
  let(:region) { 'eu-west-2' }
  let(:group) { 'example-logs' }
  let(:options) { { reporting_date: date, region:, log_group_name: group } }
  let(:client) { Aws::CloudWatchLogs::Client.new(region:, stub_responses: true) }

  def query_count = SearchAnalytics::DailyQuery.new(**options).query_definitions.size

  def fingerprints = SearchAnalytics::DailyQuery.new(**options).fingerprints

  def store_result(name, collected_at: Time.utc(2026, 9, 14, 10), fingerprint: fingerprints.fetch(name))
    SearchAnalyticsQueryResult.create(
      service: TradeTariffBackend.service,
      reporting_date: date,
      name:,
      fingerprint:,
      collected_at:,
      rows: Sequel.pg_jsonb([]),
    )
  end

  def store_complete_day
    fingerprints.each_key { |name| store_result(name) }
  end

  def postgres_connection
    opts = SearchAnalyticsQueryResult.db.opts
    PG.connect(
      host: opts[:host],
      port: opts[:port],
      dbname: opts[:database],
      user: opts[:user],
      password: opts[:password],
    )
  end

  def with_schema(connection)
    schema = SearchAnalyticsQueryResult.db.get(Sequel.function(:current_schema))
    connection.exec("SET search_path TO #{connection.escape_identifier(schema)}, public")
    connection
  end

  def unpopulate_analytics_views
    SearchAnalytics::MaterializedViews::MATVIEWS.reverse_each do |name|
      SearchAnalyticsQueryResult.db.run("REFRESH MATERIALIZED VIEW #{name} WITH NO DATA")
    end
  end

  def finish_thread(thread)
    return if thread.nil?

    raise 'refresh thread did not finish' if thread.join(15).nil?
  end

  before do
    client.stub_responses(:start_query, query_id: 'query-id')
    client.stub_responses(:get_query_results, status: 'Complete', results: [], statistics: { records_matched: 0.0 })
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_return(true)
  end

  it 'disables automatic Sidekiq retries' do
    expect(described_class.sidekiq_options).to include('retry' => false, 'queue' => :within_1_day)
  end

  it 'coordinates yesterday by default without submitting CloudWatch queries itself' do
    allow(described_class).to receive(:enqueue_day).and_return([])
    described_class.new.perform
    expect(described_class).to have_received(:enqueue_day).with(
      reporting_date: Time.current.utc.to_date - 1,
      region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
      log_group_name: SearchAnalytics::DailyQuery::SEARCH_LOG_GROUP_NAME, force: false
    )
    expect(client.api_requests).to eq([])
  end

  it 'coordinates a supplied day with the same entry point' do
    allow(described_class).to receive(:enqueue_day).and_return([])
    described_class.new.perform(date.iso8601, nil, region, group)
    expect(described_class).to have_received(:enqueue_day).with(**options, force: false)
  end

  it 'queues one job per missing group, skips successful groups and explicitly forces selected groups' do
    Sidekiq::Testing.fake! do
      described_class.clear
      described_class.enqueue_day(**options)
      expect(described_class.jobs.size).to eq(query_count)
      expect(described_class.jobs.map { |job| job['args'][1] }.uniq.size).to eq(query_count)
      expect(described_class.jobs.first['args']).to eq([date.iso8601, 'volume', region, group, false, TradeTariffBackend.service])
      described_class.clear
      SearchAnalytics::DailyQuery.new(**options, client:, queries: %w[volume]).call
      described_class.enqueue_day(**options)
      expect(described_class.jobs.size).to eq(query_count - 1)
      expect(described_class.jobs.map { |job| job['args'][1] }).not_to include('volume')
      described_class.clear
      described_class.enqueue_day(**options, queries: %w[volume], force: true)
      expect(described_class.jobs.map { |job| job['args'] }).to eq([[date.iso8601, 'volume', region, group, true, TradeTariffBackend.service]])
    end
  end

  it 'reports a rejected enqueue rather than claiming the query was scheduled' do
    allow(described_class).to receive(:perform_async).and_return(nil)
    expect { described_class.enqueue_day(**options, queries: %w[volume]) }.to raise_error(/Could not enqueue search analytics queries: volume/)
  end

  it 'attempts each planned enqueue once before reporting all rejected query names' do
    allow(described_class).to receive(:perform_async).and_return(nil, 'accepted-job', nil)

    expect { described_class.enqueue_day(**options, queries: %w[volume latency_histogram ai_cost_trend]) }
      .to raise_error('Could not enqueue search analytics queries: volume, ai_cost_trend')
    expect(described_class).to have_received(:perform_async).exactly(3).times
    %w[volume latency_histogram ai_cost_trend].each do |name|
      expect(described_class).to have_received(:perform_async).with(date.iso8601, name, region, group, false, TradeTariffBackend.service).once
    end
  end

  it 'executes only its query and reuses its success when a duplicate job arrives' do
    existing_client = client
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(existing_client)
    arguments = [date.iso8601, 'volume', region, group, false, TradeTariffBackend.service]
    described_class.new.perform(*arguments)
    described_class.new.perform(*arguments)

    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
    expect(SearchAnalyticsQueryResult.select_map(:name)).to eq(%w[volume])
  end

  it 'accepts previously queued service-first arguments without forcing a rerun' do
    existing_client = client
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(existing_client)
    described_class.new.perform(TradeTariffBackend.service, date.iso8601, 'volume', region, group, false)
    described_class.new.perform(TradeTariffBackend.service, date.iso8601, 'volume', region, group)
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
  end

  it 'preserves explicit force on previously queued service-first arguments' do
    allow(SearchAnalytics::DailyQuery).to receive(:call)
    described_class.new.perform(TradeTariffBackend.service, date.iso8601, 'volume', region, group, true)
    expect(SearchAnalytics::DailyQuery).to have_received(:call).with(**options, queries: %w[volume], force: true)
  end

  it 'leaves a failed query missing without submitting it again' do
    existing_client = client
    client.stub_responses(:get_query_results, status: 'Failed', results: [])
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(existing_client)

    expect { described_class.new.perform(date.iso8601, 'volume', region, group) }
      .to raise_error(SearchAnalytics::CloudwatchSnapshotQuery::QueryError, /Failed/)
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
    expect(SearchAnalyticsQueryResult.count).to eq(0)
    expect(SearchAnalytics::MaterializedViews).not_to have_received(:refresh!)
  end

  it 'rejects a job for another configured service before collection' do
    allow(SearchAnalytics::DailyQuery).to receive(:call)
    other_service = TradeTariffBackend.service == 'uk' ? 'xi' : 'uk'
    expect { described_class.new.perform(date.iso8601, 'volume', region, group, false, other_service) }.to raise_error(ArgumentError, /different service/)
    expect(SearchAnalytics::DailyQuery).not_to have_received(:call)
  end

  it 'refreshes only after all groups for the day are current' do
    fingerprints.except('volume').each_key { |name| store_result(name) }
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalyticsRefreshViewsWorker).to receive(:perform_async)
    described_class.new.perform(date.iso8601, 'volume', region, group)
    expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(wait: true, only_if_populated: true)
    expect(SearchAnalyticsRefreshViewsWorker).not_to have_received(:perform_async)
  end

  it 'refreshes successful journey inputs even when optional groups remain missing' do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    described_class.new.perform(date.iso8601, 'search_journeys', region, group)
    expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(wait: true, only_if_populated: true)
    expect(SearchAnalyticsQueryResult.where(reporting_date: date).select_map(:name)).to eq(%w[search_journeys])
  end

  it 'does not refresh after an unrelated query in a partially collected day' do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    described_class.new.perform(date.iso8601, 'volume', region, group)
    expect(SearchAnalytics::MaterializedViews).not_to have_received(:refresh!)
  end

  it 'can refresh an already collected day without another CloudWatch query' do
    store_complete_day
    expect(described_class.enqueue_day(**options)).to eq([])
    expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(wait: true, only_if_populated: true)
    expect(client.api_requests).to eq([])
  end

  it 'keeps a stored result reusable when refresh fails' do
    fingerprints.except('volume').each_key { |name| store_result(name) }
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::DatabaseError, 'refresh failed')
    expect { described_class.new.perform(date.iso8601, 'volume', region, group) }.to raise_error(Sequel::DatabaseError, /refresh failed/)
    expect(SearchAnalyticsQueryResult.where(reporting_date: date, name: 'volume').count).to eq(1)

    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_return(true)
    described_class.new.perform(date.iso8601, 'volume', region, group)
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
  end

  it 'uses at most three shared database lanes for all query jobs' do
    locks = []
    allow(SearchAnalyticsQueryResult.db).to receive(:with_advisory_lock) do |key, wait:, &block|
      locks << [key, wait]
      block.call
    end
    allow(SearchAnalytics::DailyQuery).to receive(:call)
    names = SearchAnalytics::DailyQuery.new(**options).query_definitions.keys
    names.each { |name| described_class.new.perform(date.iso8601, name, region, group) }

    expect(locks.map(&:first).uniq.size).to be <= 3
    expect(locks.map(&:first)).to all(be_between(described_class::LOCK_NAMESPACE, described_class::LOCK_NAMESPACE + 2))
    expect(locks.map(&:last)).to all(be(true))
  end

  it 'commits the source and releases the collection lane before refresh', :truncation do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!) do |**kwargs|
      expect(kwargs).to eq(wait: true, only_if_populated: true)
      lane = Digest::SHA256.hexdigest([TradeTariffBackend.service, date.iso8601, 'search_journeys'].to_json).to_i(16) % described_class::MAX_CONCURRENT
      checker = with_schema(postgres_connection)
      begin
        count = checker.exec_params(
          'SELECT count(*) FROM search_analytics_query_results WHERE reporting_date = $1 AND name = $2',
          [date.iso8601, 'search_journeys'],
        ).getvalue(0, 0)
        expect(count).to eq('1')
        expect(checker.exec_params('SELECT pg_try_advisory_lock($1)', [described_class::LOCK_NAMESPACE + lane]).getvalue(0, 0)).to eq('t')
        checker.exec_params('SELECT pg_advisory_unlock($1)', [described_class::LOCK_NAMESPACE + lane])
      ensure
        checker.close
      end
      true
    end

    described_class.new.perform(date.iso8601, 'search_journeys', region, group)
    expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(wait: true, only_if_populated: true)
  end

  it 'does not lose a source committed while another refresh holds the lock', :truncation do
    waiter = nil
    holder = nil
    lock_id = nil
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_call_original
    unpopulate_analytics_views
    store_result('search_journeys')
    store_result('journey_outcomes')
    SearchAnalytics::MaterializedViews.refresh!(concurrently: false, force: true)

    lock_id = SearchAnalytics::MaterializedViews.new.send(:lock_id)
    holder = postgres_connection
    holder.exec_params('SELECT pg_advisory_lock($1)', [lock_id])
    waiting = Queue.new
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_wrap_original do |original, **kwargs|
      waiting << true
      original.call(**kwargs)
    end

    waiter = Thread.new { described_class.refresh_views! }
    Timeout.timeout(5) { waiting.pop }
    later = Time.utc(2026, 9, 14, 12)
    SearchAnalyticsQueryResult.where(reporting_date: date, name: 'journey_outcomes').update(collected_at: later)
    holder.exec_params('SELECT pg_advisory_unlock($1)', [lock_id])
    holder.close
    holder = nil
    finish_thread(waiter)
    waiter = nil

    snapshot = SearchAnalyticsQueryResult.db[:search_analytics_source_revisions].where(name: 'journey_outcomes').get(:collected_at)
    expect(snapshot.utc.iso8601(6)).to eq(later.utc.iso8601(6))
  ensure
    if holder && lock_id
      holder.exec_params('SELECT pg_advisory_unlock($1)', [lock_id])
      holder.close
    end
    finish_thread(waiter)
  end

  it 'skips unpopulated views without bootstrapping', :truncation do
    unpopulate_analytics_views
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_call_original

    described_class.new.perform(date.iso8601, 'search_journeys', region, group)
    expect(SearchAnalyticsQueryResult.where(name: 'search_journeys').count).to eq(1)
    expect(SearchAnalytics::MaterializedViews.ready?).to be(false)
  ensure
    SearchAnalytics::MaterializedViews.refresh!(concurrently: false, force: true)
  end

  it 'waits for an overlapping bootstrap then rebuilds the new source', :truncation do
    waiter = nil
    holder = nil
    lock_id = nil
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_call_original
    unpopulate_analytics_views
    store_result('search_journeys')
    store_result('journey_outcomes')

    lock_id = SearchAnalytics::MaterializedViews.new.send(:lock_id)
    holder = with_schema(postgres_connection)
    holder.exec_params('SELECT pg_advisory_lock($1)', [lock_id])
    holder.exec('BEGIN ISOLATION LEVEL REPEATABLE READ')
    holder.exec("SELECT id, collected_at FROM search_analytics_query_results WHERE name IN ('search_journeys', 'journey_outcomes')")

    waiting = Queue.new
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_wrap_original do |original, **kwargs|
      waiting << true
      original.call(**kwargs)
    end

    waiter = Thread.new { described_class.refresh_views! }
    Timeout.timeout(5) { waiting.pop }
    later = Time.utc(2026, 9, 14, 12)
    SearchAnalyticsQueryResult.where(reporting_date: date, name: 'search_journeys').update(collected_at: later)
    SearchAnalytics::MaterializedViews::MATVIEWS.each do |name|
      holder.exec("REFRESH MATERIALIZED VIEW #{name}")
    end
    holder.exec('COMMIT')
    holder.exec_params('SELECT pg_advisory_unlock($1)', [lock_id])
    holder.close
    holder = nil
    finish_thread(waiter)
    waiter = nil

    snapshot = SearchAnalyticsQueryResult.db[:search_analytics_source_revisions].where(name: 'search_journeys').get(:collected_at)
    expect(snapshot.utc.iso8601(6)).to eq(later.utc.iso8601(6))
  ensure
    if holder
      begin
        holder.exec('ROLLBACK')
      rescue PG::Error
        nil
      end
      holder.exec_params('SELECT pg_advisory_unlock($1)', [lock_id]) if lock_id
      holder.close
    end
    finish_thread(waiter)
  end
end
