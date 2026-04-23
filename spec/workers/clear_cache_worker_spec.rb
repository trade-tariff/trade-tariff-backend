RSpec.describe ClearCacheWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:redis) { instance_double(Redis) }
  let(:redis_pool) { instance_double(ConnectionPool) }
  let(:cache_store) { instance_double(ActiveSupport::Cache::RedisCacheStore) }
  let(:namespace) { 'test-namespace' }

  let(:preserved_keys) do
    {
      "#{namespace}:myott_all_active_commodities" => { value: '["a","b"]', ttl: 3600 },
      "#{namespace}:myott_all_expired_commodities" => { value: '["c","d"]', ttl: 7200 },
      "#{namespace}:_commodity-description-v1-1234567890" => { value: 'Test commodity', ttl: 604_800 },
    }
  end

  before do
    allow(Rails).to receive(:cache).and_return(cache_store)
    allow(cache_store).to receive_messages(redis: redis_pool, options: { namespace: namespace })
    allow(redis_pool).to receive(:with).and_yield(redis)
    allow(cache_store).to receive(:clear)
    allow(TradeTariffBackend.frontend_redis).to receive(:flushdb)
    allow(Sidekiq::Client).to receive(:enqueue)
    allow(Sidekiq::Client).to receive(:enqueue_in)
    allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
    allow(ActiveSupport::Notifications).to receive(:instrument).with(
      TradeTariffBackend::TariffUpdateEventListener::TARIFF_CACHE_CLEARED,
      anything,
    )

    allow(redis).to receive(:scan_each) do |match:, &block|
      preserved_keys.each_key do |key|
        block.call(key) if key.match?(Regexp.escape(match).gsub('\*', '.*'))
      end
    end

    allow(redis).to receive(:get) do |key|
      preserved_keys.dig(key, :value)
    end

    allow(redis).to receive(:ttl) do |key|
      preserved_keys.dig(key, :ttl) || -1
    end

    allow(redis).to receive(:set)

    silence do
      worker.perform
    end
  end

  it 'preserves keys with their TTLs across clear' do
    preserved_keys.each do |key, data|
      expect(redis).to have_received(:get).with(key)
      expect(redis).to have_received(:ttl).with(key)
      expect(redis).to have_received(:set).with(key, data[:value], ex: data[:ttl])
    end
  end

  it 'scans for active commodities keys' do
    expect(redis).to have_received(:scan_each).with(
      match: "#{namespace}:#{Api::User::ActiveCommoditiesService::MYOTT_ALL_ACTIVE_COMMODITIES_CACHE_KEY}*",
    )
  end

  it 'scans for expired commodities keys' do
    expect(redis).to have_received(:scan_each).with(
      match: "#{namespace}:#{Api::User::ActiveCommoditiesService::MYOTT_ALL_EXPIRED_COMMODITIES_CACHE_KEY}*",
    )
  end

  it 'scans for commodity description keys' do
    expect(redis).to have_received(:scan_each).with(
      match: "#{namespace}:#{CachedCommodityDescriptionService::CACHE_PREFIX}*",
    )
  end

  it { expect(cache_store).to have_received(:clear) }
  it { expect(TradeTariffBackend.frontend_redis).to have_received(:flushdb) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrecacheHeadingsWorker, Time.zone.today.to_formatted_s(:db)) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrewarmQuotaOrderNumbersWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(PrewarmCommoditiesWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue).with(ReindexModelsWorker) }
  it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(1.minute, InvalidateCacheWorker) }

  it 'instruments the tariff cache cleared event' do
    expect(ActiveSupport::Notifications).to have_received(:instrument).with(
      TradeTariffBackend::TariffUpdateEventListener::TARIFF_CACHE_CLEARED,
      service: TradeTariffBackend.service,
    )
  end

  context 'when keys have no expiry (TTL -1)' do
    let(:no_expiry_keys) do
      {
        "#{namespace}:myott_all_active_commodities" => { value: '["a","b"]', ttl: -1 },
      }
    end

    before do
      allow(redis).to receive(:scan_each) do |match:, &block|
        no_expiry_keys.each_key do |key|
          block.call(key) if key.match?(Regexp.escape(match).gsub('\*', '.*'))
        end
      end

      allow(redis).to receive(:get) do |key|
        no_expiry_keys.dig(key, :value)
      end

      allow(redis).to receive(:ttl).and_return(-1)
      allow(redis).to receive(:set)

      silence do
        worker.perform
      end
    end

    it 'restores keys without expiry' do
      no_expiry_keys.each do |key, data|
        expect(redis).to have_received(:set).with(key, data[:value])
      end
    end
  end
end
