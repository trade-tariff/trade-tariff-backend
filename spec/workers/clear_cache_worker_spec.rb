RSpec.describe ClearCacheWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:preserved_keys) do
    [
      Api::User::ActiveCommoditiesService::MYOTT_ALL_ACTIVE_COMMODITIES_CACHE_KEY,
      Api::User::ActiveCommoditiesService::MYOTT_ALL_EXPIRED_COMMODITIES_CACHE_KEY,
    ]
  end

  let(:preserved_values) do
    {
      'myott_all_active_commodities' => %w[a b],
      'myott_all_expired_commodities' => %w[c d],
    }
  end

  before do
    allow(Rails.cache).to receive(:read_multi).and_return(preserved_values)
    allow(Rails.cache).to receive(:clear)
    allow(Rails.cache).to receive(:write)
    allow(TradeTariffBackend.frontend_redis).to receive(:flushdb)
    allow(Sidekiq::Client).to receive(:enqueue)
    allow(Sidekiq::Client).to receive(:enqueue_in)

    silence do
      worker.perform
    end
  end

  it 'preserves specified cache keys across clear' do
    expect(Rails.cache).to have_received(:read_multi).with(*preserved_keys)
    preserved_values.each do |key, value|
      expect(Rails.cache).to have_received(:write).with(key, value)
    end
  end

  it { expect(Rails.cache).to have_received(:clear) }
  it { expect(TradeTariffBackend.frontend_redis).to have_received(:flushdb) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrecacheHeadingsWorker, Time.zone.today.to_s) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrewarmQuotaOrderNumbersWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(ReindexModelsWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(1.minute, InvalidateCacheWorker) }
end
