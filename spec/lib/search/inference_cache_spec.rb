RSpec.describe Search::InferenceCache do
  let(:key) { described_class.key(operation: 'interactive_search', inputs: { context: 'prompt' }) }
  let(:value) { { 'answers' => [{ 'commodity_code' => '4202210000', 'confidence' => 'strong' }] } }
  let(:redis) { Redis.new(**TradeTariffBackend.redis_config) }
  let(:stored_key) { "#{described_class.namespace}:#{key}" }

  around do |example|
    described_class.store.clear
    example.run
  ensure
    described_class.store.clear
    redis.close
  end

  def write(entry = value)
    described_class.write(key, entry, operation: 'interactive_search', request_id: 'journey')
  end

  def read(&)
    described_class.read(key, operation: 'interactive_search', request_id: 'journey', &)
  end

  context 'when disabled' do
    before { allow(TradeTariffBackend).to receive(:search_inference_cache_enabled?).and_return(false) }

    it 'does not store output' do
      write

      expect(redis.exists?(stored_key)).to be(false)
    end
  end

  context 'when enabled' do
    before { allow(TradeTariffBackend).to receive(:search_inference_cache_enabled?).and_return(true) }

    it 'returns stored output' do
      write

      expect(read).to eq(value)
    end

    it 'stores plain JSON for seven days', :aggregate_failures do
      write

      expect(JSON.parse(redis.get(stored_key))).to eq(value)
      expect(redis.ttl(stored_key)).to be_between(described_class::TTL.to_i - 5, described_class::TTL.to_i)
    end

    it 'survives a namespaced Rails cache clear', :aggregate_failures do
      rails_cache = ActiveSupport::Cache::RedisCacheStore.new(**TradeTariffBackend.redis_config, namespace: 'rails-cache-uk')
      rails_cache.write('tariff-response', 'cached')
      write

      rails_cache.clear

      expect(rails_cache.read('tariff-response')).to be_nil
      expect(read).to eq(value)
    end

    it 'deletes a rejected entry', :aggregate_failures do
      write

      expect(read { false }).to be_nil
      expect(redis.exists?(stored_key)).to be(false)
    end

    it 'treats malformed JSON as a miss' do
      redis.set(stored_key, '{')

      expect(read).to be_nil
    end

    it 'does not store oversized output' do
      write('answers' => 'x' * described_class::MAX_PAYLOAD_BYTES)

      expect(redis.exists?(stored_key)).to be(false)
    end

    it 'reports outcomes without query text' do
      events = []
      subscriber = ->(event) { events << event.payload }

      ActiveSupport::Notifications.subscribed(subscriber, 'inference_cache_access.search') do
        read
        write
        read
      end

      expect(events.pluck(:outcome)).to eq(%w[miss write hit])
    end

    context 'when Redis is unavailable' do
      before { allow(described_class.store.redis).to receive(:then).and_raise(Redis::CannotConnectError) }

      it 'falls back to a miss' do
        expect(read).to be_nil
      end
    end
  end
end
