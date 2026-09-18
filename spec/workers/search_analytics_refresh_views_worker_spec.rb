RSpec.describe SearchAnalyticsRefreshViewsWorker do
  let(:service) { TradeTariffBackend.service }

  before do
    allow(SearchAnalyticsQueryWorker).to receive(:refresh_views!).and_return(true)
  end

  it 'delegates already-queued jobs to the same synchronous refresh' do
    described_class.new.perform
    expect(SearchAnalyticsQueryWorker).to have_received(:refresh_views!)
  end

  it 'keeps already-enqueued service-only jobs on the same refresh path' do
    described_class.new.perform(service)
    expect(SearchAnalyticsQueryWorker).to have_received(:refresh_views!)
  end

  it 'ignores a leftover token argument from an already-enqueued followup' do
    described_class.new.perform(service, 'old-token')
    expect(SearchAnalyticsQueryWorker).to have_received(:refresh_views!)
  end

  it 'uses the same wait and skip flags as collection' do
    allow(SearchAnalyticsQueryWorker).to receive(:refresh_views!).and_call_original
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_return(true)
    described_class.new.perform(service, 'old-token')
    expect(SearchAnalytics::MaterializedViews).to have_received(:refresh!).with(wait: true, only_if_populated: true)
  end

  it 'does not schedule a followup when refresh fails' do
    allow(SearchAnalyticsQueryWorker).to receive(:refresh_views!).and_raise(Sequel::DatabaseError, 'refresh failed')
    expect(described_class).not_to receive(:perform_in)
    expect { described_class.new.perform }.to raise_error(Sequel::DatabaseError, /refresh failed/)
    expect(described_class.sidekiq_options).to include('queue' => :within_1_day, 'retry' => false)
  end

  it 'does not schedule a followup when the helper lock is busy' do
    allow(SearchAnalyticsQueryWorker).to receive(:refresh_views!).and_raise(Sequel::AdvisoryLockError)
    expect(described_class).not_to receive(:perform_in)
    expect { described_class.new.perform(service, 'old-token') }.to raise_error(Sequel::AdvisoryLockError)
  end

  it 'rejects another service before touching any view' do
    other = service == 'uk' ? 'xi' : 'uk'
    expect(SearchAnalyticsQueryWorker).not_to receive(:refresh_views!)
    expect { described_class.new.perform(other) }.to raise_error(ArgumentError, /different service/)
  end
end
