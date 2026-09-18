RSpec.describe SearchAnalyticsQueryWorker, type: :worker do
  let(:date) { Date.new(2026, 9, 14) }
  let(:region) { 'eu-west-2' }
  let(:group) { 'example-logs' }
  let(:options) { { reporting_date: date, region:, log_group_name: group } }
  let(:client) { Aws::CloudWatchLogs::Client.new(region:, stub_responses: true) }

  def query_count = SearchAnalytics::DailyQuery.new(**options).query_definitions.size

  before do
    client.stub_responses(:start_query, query_id: 'query-id')
    client.stub_responses(:get_query_results, status: 'Complete', results: [], statistics: { records_matched: 0.0 })
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
  end

  it 'rejects a job for another configured service before collection' do
    allow(SearchAnalytics::DailyQuery).to receive(:call)
    other_service = TradeTariffBackend.service == 'uk' ? 'xi' : 'uk'
    expect { described_class.new.perform(date.iso8601, 'volume', region, group, false, other_service) }.to raise_error(ArgumentError, /different service/)
    expect(SearchAnalytics::DailyQuery).not_to have_received(:call)
  end

  it 'queues a refresh only after all groups for the day are current' do
    definitions = SearchAnalytics::DailyQuery.new(**options).fingerprints
    definitions.except('volume').each do |name, fingerprint|
      SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: date, name:, fingerprint:, collected_at: Time.current, rows: Sequel.pg_jsonb([]))
    end
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalyticsRefreshViewsWorker).to receive(:perform_async).and_return('refresh-job')
    described_class.new.perform(date.iso8601, 'volume', region, group)
    expect(SearchAnalyticsRefreshViewsWorker).to have_received(:perform_async).with(TradeTariffBackend.service)
  end

  it 'refreshes successful journey inputs even when optional groups remain missing' do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalyticsRefreshViewsWorker).to receive(:perform_async).and_return('refresh-job')
    described_class.new.perform(date.iso8601, 'search_journeys', region, group)
    expect(SearchAnalyticsRefreshViewsWorker).to have_received(:perform_async).with(TradeTariffBackend.service)
    expect(SearchAnalyticsQueryResult.where(reporting_date: date).select_map(:name)).to eq(%w[search_journeys])
  end

  it 'does not refresh after an unrelated query in a partially collected day' do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    expect(SearchAnalyticsRefreshViewsWorker).not_to receive(:perform_async)
    described_class.new.perform(date.iso8601, 'volume', region, group)
  end

  it 'can refresh an already collected day without another CloudWatch query' do
    SearchAnalytics::DailyQuery.new(**options).fingerprints.each do |name, fingerprint|
      SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: date, name:, fingerprint:, collected_at: Time.current, rows: Sequel.pg_jsonb([]))
    end
    allow(SearchAnalyticsRefreshViewsWorker).to receive(:perform_async).and_return('refresh-job')
    expect(described_class.enqueue_day(**options)).to eq([])
    expect(SearchAnalyticsRefreshViewsWorker).to have_received(:perform_async).with(TradeTariffBackend.service)
    expect(client.api_requests).to eq([])
  end

  it 'reports refresh enqueue failure while preserving the successful collection' do
    SearchAnalytics::DailyQuery.new(**options).fingerprints.except('volume').each do |name, fingerprint|
      SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: date, name:, fingerprint:, collected_at: Time.current, rows: Sequel.pg_jsonb([]))
    end
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(client)
    allow(SearchAnalyticsRefreshViewsWorker).to receive(:perform_async).and_return(nil)
    expect { described_class.new.perform(date.iso8601, 'volume', region, group) }.to raise_error(/results are stored/)
    expect(SearchAnalyticsQueryResult.where(reporting_date: date, name: 'volume').count).to eq(1)
  end

  it 'uses at most three shared database lanes for all query jobs' do
    db = SearchAnalyticsQueryResult.db
    locks = []
    allow(db).to receive(:with_advisory_lock) do |key, wait:, &block|
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
end
