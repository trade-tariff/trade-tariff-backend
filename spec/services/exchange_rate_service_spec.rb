RSpec.describe ExchangeRateService do
  subject(:service) { described_class.new }

  let(:now) { Time.zone.parse('2021-03-11T18:10:44Z') }

  before do
    TradeTariffBackend.redis.flushdb
    allow(Time.zone).to receive(:now).and_return(now)
  end

  describe '#call' do
    let(:expected_cache) do
      expected = expected_result.dup
      expected['expires_at'] = expected['expires_at'].iso8601
      expected.to_json
    end

    context 'when fetching for the first time' do
      before do
        stub_request(:get, 'http://api.exchangeratesapi.io/v1/latest?access_key=')
          .to_return(status: 200, body: '{"foo":"bar"}')
      end

      let(:expected_result) do
        {
          'foo' => 'bar',
          'expires_at' => Time.zone.parse('2021-03-12T15:15:0Z'),
        }
      end

      it 'returns newly fetched exchange rates' do
        expect(service.call).to eq(expected_result)
      end

      it 'caches the newly fetched exchange rates' do
        expect { service.call }
          .to change { TradeTariffBackend.redis.get(described_class::REDIS_KEY) }
          .from(nil)
          .to(expected_cache)
      end
    end

    context 'when the exchange rates are expired' do
      before do
        TradeTariffBackend.redis.set(described_class::REDIS_KEY, previously_cached_result)
        stub_request(:get, 'http://api.exchangeratesapi.io/v1/latest?access_key=')
          .to_return(status: 200, body: '{"baz":"qux"}')
      end

      let(:expected_result) do
        {
          'baz' => 'qux',
          'expires_at' => Time.zone.parse('2021-03-12T15:15:0Z'),
        }
      end
      let(:previously_cached_result) do
        {
          'foo' => 'bar',
          'expires_at' => (now - 1.second).iso8601,
        }.to_json
      end

      it 'returns the fetched exchange rates' do
        expect(service.call).to eq(expected_result)
      end

      it 'caches the newly fetched exchange rates' do
        expect { service.call }
          .to change { TradeTariffBackend.redis.get(described_class::REDIS_KEY) }
          .from(previously_cached_result)
          .to(expected_cache)
      end
    end

    context 'when the exchange rates are current' do
      before do
        TradeTariffBackend.redis.set(described_class::REDIS_KEY, previously_cached_result)
        stub_request(:get, 'http://api.exchangeratesapi.io/v1/latest?access_key=')
          .to_return(status: 200, body: '{"baz":"qux"}')
      end

      let(:expected_result) do
        {
          'foo' => 'bar',
          'expires_at' => Time.zone.parse('2021-03-12T15:14:0Z'),
        }
      end
      let(:previously_cached_result) do
        expected = expected_result.dup
        expected['expires_at'] = expected['expires_at'].iso8601
        expected.to_json
      end

      it 'returns the cached exchange rates' do
        expect(service.call).to eq(expected_result)
      end

      it 'does not update the cache' do
        expect { service.call }
          .not_to change { TradeTariffBackend.redis.get(described_class::REDIS_KEY) }
          .from(previously_cached_result)
      end
    end
  end
end
