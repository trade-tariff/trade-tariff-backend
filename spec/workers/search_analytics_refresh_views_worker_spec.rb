RSpec.describe SearchAnalyticsRefreshViewsWorker do
  let(:service) { TradeTariffBackend.service }

  it 'refreshes without waiting and without bootstrapping unpopulated views' do
    expect(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform
  end

  it 'does not consult ready? before the helper holds the lock' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    expect(SearchAnalytics::MaterializedViews).not_to receive(:ready?)
    described_class.new.perform
  end

  it 'keeps already-enqueued service-only jobs and delayed followups on the same refresh path' do
    expect(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform(service)
  end

  it 'ignores a leftover token argument from an already-enqueued followup' do
    expect(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform(service, 'old-token')
  end

  it 'schedules a delayed followup when the refresh lock is busy' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return('followup-job')
    described_class.new.perform
    expect(described_class).to have_received(:perform_in).with(described_class::FOLLOWUP_INTERVAL, service)
  end

  it 'lets a busy followup schedule a successor without another collection signal' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return('followup-job')
    described_class.new.perform(service, 'old-token')
    expect(described_class).to have_received(:perform_in).with(described_class::FOLLOWUP_INTERVAL, service)
  end

  it 'does not let an old token or leftover lease suppress a followup' do
    Sidekiq.redis { |redis| redis.set("search_analytics:refresh_views:followup:#{service}", 'stale-lease', ex: 600) }
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return('followup-job')
    described_class.new.perform(service, 'stale-token')
    expect(described_class).to have_received(:perform_in).with(described_class::FOLLOWUP_INTERVAL, service)
  ensure
    Sidekiq.redis { |redis| redis.del("search_analytics:refresh_views:followup:#{service}") }
  end

  it 'keeps a successful followup when a concurrent enqueue then returns nil' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    started = Queue.new
    release = Queue.new
    enqueued = []
    allow(described_class).to receive(:perform_in) do
      if Thread.current[:refresh_enqueue] == :first
        started << true
        release.pop
        nil
      else
        enqueued << 'kept-job'
        'kept-job'
      end
    end

    first = Thread.new do
      Thread.current[:refresh_enqueue] = :first
      expect { described_class.new.perform }.to raise_error(/could not be queued/)
    end
    Timeout.timeout(5) { started.pop }
    described_class.new.perform
    release << true
    expect(first.join(5)).to eq(first)
    expect(enqueued).to eq(%w[kept-job])
    expect(described_class).to have_received(:perform_in).twice
  end

  it 'keeps a successful followup when a concurrent enqueue then raises' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    started = Queue.new
    release = Queue.new
    enqueued = []
    allow(described_class).to receive(:perform_in) do
      if Thread.current[:refresh_enqueue] == :first
        started << true
        release.pop
        raise 'enqueue failed'
      else
        enqueued << 'kept-job'
        'kept-job'
      end
    end

    first = Thread.new do
      Thread.current[:refresh_enqueue] = :first
      expect { described_class.new.perform }.to raise_error(RuntimeError, 'enqueue failed')
    end
    Timeout.timeout(5) { started.pop }
    described_class.new.perform
    release << true
    expect(first.join(5)).to eq(first)
    expect(enqueued).to eq(%w[kept-job])
    expect(described_class).to have_received(:perform_in).twice
  end

  it 'rejects another service before touching any view' do
    other = service == 'uk' ? 'xi' : 'uk'
    expect(SearchAnalytics::MaterializedViews).not_to receive(:refresh!)
    expect { described_class.new.perform(other) }.to raise_error(ArgumentError, /different service/)
  end

  it 'reports database errors without an automatic retry or followup' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::DatabaseError, 'refresh failed')
    expect(described_class).not_to receive(:perform_in)
    expect { described_class.new.perform }.to raise_error(Sequel::DatabaseError, /refresh failed/)
    expect(described_class.sidekiq_options).to include('queue' => :within_1_day, 'retry' => false)
  end
end
