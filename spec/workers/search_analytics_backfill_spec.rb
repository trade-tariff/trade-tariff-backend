RSpec.describe 'Search analytics backfill', type: :worker do
  let(:now) { Time.utc(2026, 9, 16, 12) }
  let(:yesterday) { now.to_date - 1 }
  let(:scope) { { region: 'eu-west-2', log_group_name: 'example-logs' } }
  let(:jobs) { SearchAnalyticsQueryWorker.jobs }

  around do |example|
    Sidekiq::Testing.fake! do
      SearchAnalyticsQueryWorker.clear
      example.run
      SearchAnalyticsQueryWorker.clear
    end
  end

  before do
    allow(Aws::CloudWatchLogs::Client).to receive(:new).and_raise('Backfill enqueue must not call AWS')
  end

  def enqueue(**options) = SearchAnalyticsQueryWorker.enqueue_backfill(**scope, now:, **options)

  def store_day(date, except: nil)
    SearchAnalytics::DailyQuery.new(reporting_date: date, **scope, now:).fingerprints.each do |name, fingerprint|
      next if name == except

      SearchAnalyticsQueryResult.create(service: TradeTariffBackend.service, reporting_date: date, name:, fingerprint:, rows: Sequel.pg_jsonb([]), collected_at: now)
    end
  end

  it 'defaults to 30 completed UTC days and queues one coordinator per day newest first' do
    expect(enqueue.size).to eq(30)
    expect(jobs.map { |job| job['args'].first }).to eq(Array.new(30) { |offset| (yesterday - offset).iso8601 })
    expect(jobs.map { |job| job['args'][1] }).to all(be_nil)
    expect(jobs.map { |job| job['args'][4] }).to all(be(false))
    expect(jobs.map { |job| job['args'].last }).to all(eq(TradeTariffBackend.service))
  end

  it 'skips complete days and queues a day with a missing query' do
    store_day(yesterday)
    store_day(yesterday - 1, except: 'ai_cost_trend')
    expect(enqueue(days: 2).size).to eq(1)
    expect(jobs.first['args'].first).to eq((yesterday - 1).iso8601)
  end

  it 'lets each coordinator queue only the query still missing when it starts' do
    store_day(yesterday, except: 'ai_cost_trend')
    enqueue(days: 1)
    coordinator = jobs.shift
    SearchAnalyticsQueryWorker.new.perform(*coordinator['args'])
    expect(jobs.size).to eq(1)
    expect(jobs.first['args'][1]).to eq('ai_cost_trend')
  end

  it 'does nothing if another process filled the gap before the coordinator runs' do
    enqueue(days: 1)
    coordinator = jobs.shift
    store_day(yesterday)
    SearchAnalyticsQueryWorker.new.perform(*coordinator['args'])
    expect(jobs).to eq([])
  end

  it 'queues complete days when force is explicit without deleting the current results' do
    store_day(yesterday)
    expect { enqueue(days: 1, force: true) }.not_to change(SearchAnalyticsQueryResult, :count)
    coordinator = jobs.shift
    expect(coordinator['args'][4]).to be(true)
    SearchAnalyticsQueryWorker.new.perform(*coordinator['args'])
    expect(jobs.size).to eq(8)
    expect(jobs.map { |job| job['args'][4] }).to all(be(true))
  end

  it 'queues stale definitions but leaves matching successful groups reusable' do
    store_day(yesterday)
    SearchAnalyticsQueryResult.where(name: 'volume').update(fingerprint: 'old')
    enqueue(days: 1)
    coordinator = jobs.shift
    SearchAnalyticsQueryWorker.new.perform(*coordinator['args'])
    expect(jobs.map { |job| job['args'][1] }).to eq(%w[volume])
  end

  it 'rejects invalid day counts before enqueueing anything' do
    [0, -1, 367, 1.5, '30', nil].each do |days|
      expect { enqueue(days:) }.to raise_error(ArgumentError, /DAYS/)
    end
    expect(jobs).to eq([])
  end

  it 'derives yesterday from UTC rather than the local time zone' do
    time = Time.new(2026, 9, 16, 0, 30, 0, '+02:00')
    SearchAnalyticsQueryWorker.enqueue_backfill(**scope, days: 1, now: time)
    expect(jobs.first['args'].first).to eq('2026-09-14')
  end

  it 'reports rejected days after trying the other days once, without retries' do
    allow(SearchAnalyticsQueryWorker).to receive(:perform_async).and_return(nil, 'accepted', nil)
    expect { enqueue(days: 3) }.to raise_error("Could not enqueue search analytics days: #{yesterday}, #{yesterday - 2}")
    expect(SearchAnalyticsQueryWorker).to have_received(:perform_async).exactly(3).times
  end
end
