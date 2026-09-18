RSpec.describe SearchAnalyticsRefreshViewsWorker do
  before { allow(SearchAnalytics::MaterializedViews).to receive(:ready?).and_return(true) }

  it 'does not populate views before explicit bootstrap' do
    allow(SearchAnalytics::MaterializedViews).to receive(:ready?).and_return(false)
    expect(SearchAnalytics::MaterializedViews).not_to receive(:refresh!)
    described_class.new.perform
  end

  it 'waits for the refresh lock so the final completion is not dropped' do
    expect(SearchAnalytics::MaterializedViews).to receive(:refresh!).with(wait: true)
    described_class.new.perform(TradeTariffBackend.service)
  end

  it 'rejects another service before touching any view' do
    other = TradeTariffBackend.service == 'uk' ? 'xi' : 'uk'
    expect(SearchAnalytics::MaterializedViews).not_to receive(:refresh!)
    expect { described_class.new.perform(other) }.to raise_error(ArgumentError, /different service/)
  end

  it 'reports database errors without an automatic retry' do
    allow(SearchAnalytics::MaterializedViews).to receive(:refresh!).and_raise(Sequel::DatabaseError, 'refresh failed')
    expect { described_class.new.perform }.to raise_error(Sequel::DatabaseError, /refresh failed/)
    expect(described_class.sidekiq_options).to include('queue' => :within_1_day, 'retry' => false)
  end
end
