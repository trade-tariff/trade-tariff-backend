RSpec.describe SearchAnalyticsQueryWorker, type: :worker do
  let(:date) { Date.new(2026, 9, 14) }
  let(:region) { 'eu-west-2' }
  let(:group) { 'example-logs' }
  let(:options) { { reporting_date: date, region:, log_group_name: group } }
  let(:client) { Aws::CloudWatchLogs::Client.new(region:, stub_responses: true) }

  before do
    client.stub_responses(:start_query, query_id: 'query-id')
    client.stub_responses(:get_query_results, status: 'Complete', results: [], statistics: { records_matched: 0.0 })
  end

  it 'disables automatic Sidekiq retries' do
    expect(described_class.sidekiq_options).to include('retry' => false, 'queue' => :within_1_day)
  end

  it 'queues one job per missing group, skips successful groups and explicitly forces selected groups' do
    Sidekiq::Testing.fake! do
      described_class.clear
      described_class.enqueue_day(**options)
      expect(described_class.jobs.size).to eq(9)
      expect(described_class.jobs.map { |job| job['args'][2] }.uniq.size).to eq(9)
      expect(described_class.jobs.first['args']).to eq([TradeTariffBackend.service, date.iso8601, 'volume', region, group, false])
      described_class.clear
      SearchAnalytics::DailyQuery.new(**options, client:, queries: %w[volume]).call
      described_class.enqueue_day(**options)
      expect(described_class.jobs.size).to eq(8)
      expect(described_class.jobs.map { |job| job['args'][2] }).not_to include('volume')
      described_class.clear
      described_class.enqueue_day(**options, queries: %w[volume], force: true)
      expect(described_class.jobs.map { |job| job['args'] }).to eq([[TradeTariffBackend.service, date.iso8601, 'volume', region, group, true]])
    end
  end

  it 'executes only its query and reuses its success when a duplicate job arrives' do
    existing_client = client
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(existing_client)
    arguments = [TradeTariffBackend.service, date.iso8601, 'volume', region, group]
    described_class.new.perform(*arguments)
    described_class.new.perform(*arguments)

    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
    expect(SearchAnalyticsQueryResult.select_map(:name)).to eq(%w[volume])
  end

  it 'leaves a failed query missing without submitting it again' do
    existing_client = client
    client.stub_responses(:get_query_results, status: 'Failed', results: [])
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_return(existing_client)

    expect { described_class.new.perform(TradeTariffBackend.service, date.iso8601, 'volume', region, group) }
      .to raise_error(SearchAnalytics::CloudwatchSnapshotQuery::QueryError, /Failed/)
    expect(client.api_requests.count { |request| request[:operation_name] == :start_query }).to eq(1)
    expect(SearchAnalyticsQueryResult.count).to eq(0)
  end

  it 'rejects a job for another configured service before collection' do
    allow(SearchAnalytics::DailyQuery).to receive(:call)
    other_service = TradeTariffBackend.service == 'uk' ? 'xi' : 'uk'
    expect { described_class.new.perform(other_service, date.iso8601, 'volume', region, group) }.to raise_error(ArgumentError, /different service/)
    expect(SearchAnalytics::DailyQuery).not_to have_received(:call)
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
    names.each { |name| described_class.new.perform(TradeTariffBackend.service, date.iso8601, name, region, group) }

    expect(locks.map(&:first).uniq.size).to be <= 3
    expect(locks.map(&:first)).to all(be_between(described_class::LOCK_NAMESPACE, described_class::LOCK_NAMESPACE + 2))
    expect(locks.map(&:last)).to all(be(true))
  end
end
