RSpec.describe SearchAnalyticsRefreshViewsWorker do
  let(:service) { TradeTariffBackend.service }
  let(:key) { described_class.followup_key(service) }

  def lease = Sidekiq.redis { |redis| redis.get(key) }

  def write_lease(token)
    Sidekiq.redis { |redis| redis.set(key, token, ex: described_class::FOLLOWUP_LEASE) }
  end

  before do
    stub_const(
      'SearchAnalyticsRefreshViewsWorker::FOLLOWUP_KEY_PREFIX',
      "search_analytics:refresh_views:followup:spec:#{SecureRandom.uuid}:",
    )
  end

  after { Sidekiq.redis { |redis| redis.del(key) } }

  it 'refreshes without waiting and without bootstrapping unpopulated views' do
    expect(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform
  end

  it 'does not consult ready? before the helper holds the lock' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    expect(SearchAnalytics::MaterializedViews).not_to receive(:ready?)
    described_class.new.perform
  end

  it 'keeps already-enqueued service-only jobs on the same refresh path' do
    expect(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform(service)
  end

  it 'does not clear another job\'s pending lease after a successful refresh' do
    write_lease('pending-token')
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform
    expect(lease).to eq('pending-token')
  end

  it 'schedules one delayed followup when the refresh lock is busy' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return('followup-job')
    described_class.new.perform
    expect(described_class).to have_received(:perform_in).with(described_class::FOLLOWUP_INTERVAL, service, kind_of(String)).once
    expect(lease).to be_present
  end

  it 'coalesces concurrent busy-lock signals onto one followup' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return('followup-job')
    threads = Array.new(2) { Thread.new { described_class.new.perform } }
    threads.each { |thread| expect(thread.join(5)).to eq(thread) }
    expect(described_class).to have_received(:perform_in).once
  end

  it 'lets a followup that still finds a busy lock schedule the next delay' do
    token = SecureRandom.uuid
    write_lease(token)
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return('followup-job')
    described_class.new.perform(service, token)
    expect(described_class).to have_received(:perform_in).with(described_class::FOLLOWUP_INTERVAL, service, kind_of(String)).once
    expect(lease).to be_present
    expect(lease).not_to eq(token)
  end

  it 'does not let a stale token clear a newer lease' do
    write_lease('new-token')
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: false, only_if_populated: true)
    described_class.new.perform(service, 'stale-token')
    expect(lease).to eq('new-token')
  end

  it 'releases only its own token when delayed enqueue is rejected' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_return(nil)
    expect { described_class.new.perform }.to raise_error(/could not be queued/)
    expect(lease).to be_nil
  end

  it 'releases only its own token when delayed enqueue raises' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::AdvisoryLockError)
    allow(described_class).to receive(:perform_in).and_raise(RuntimeError, 'enqueue failed')
    expect { described_class.new.perform }.to raise_error(RuntimeError, 'enqueue failed')
    expect(lease).to be_nil
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
