RSpec.describe QueuedSearch do
  subject(:search) { described_class.create(params: { q: 'horse' }, context: {}) }

  after { search.delete }

  describe '.create' do
    it 'stores an expiring queued payload' do
      expect(search.payload).to include('id' => search.id, 'status' => 'queued', 'params' => { 'q' => 'horse' })
      ttl = Sidekiq.redis { |redis| redis.ttl(search.key) }
      expect(ttl).to be_between(1, 1.hour.to_i)
    end
  end

  describe '#claim' do
    it 'allows only one worker to claim work' do
      expect(search.claim).to include('status' => 'running')
      expect(described_class.new(search.id).claim).to be_nil
    end

    it 'claims once across concurrent workers' do
      id = search.id
      claims = Array.new(5) { Thread.new { described_class.new(id).claim } }.map(&:value)

      expect(claims.compact.size).to eq(1)
    end

    it 'does not claim expired work' do
      search.delete

      expect(search.claim).to be_nil
      expect(search.payload).to be_nil
    end
  end

  describe '#payload' do
    it 'isolates UK and XI payloads' do
      id = search.id
      allow(TradeTariffBackend).to receive(:service).and_return('xi')

      expect(described_class.new(id).payload).to be_nil
    ensure
      allow(TradeTariffBackend).to receive(:service).and_call_original
    end
  end

  describe '#finish' do
    it 'preserves expiry through transitions' do
      Sidekiq.redis { |redis| redis.expire(search.key, 60) }
      search.claim
      search.finish(result: { data: [] }, response_status: 200)

      expect(search.payload).to include('status' => 'completed', 'result' => { 'data' => [] })
      expect(Sidekiq.redis { |redis| redis.ttl(search.key) }).to be_between(1, 60)
    end

    it 'does not overwrite a terminal result' do
      search.claim
      search.finish(result: { data: [] }, response_status: 200)
      search.finish(result: { errors: [] }, response_status: 500)

      expect(search.payload).to include('status' => 'completed', 'response_status' => 200)
    end

    it 'does not resurrect expired work' do
      search.claim
      search.delete
      search.finish(result: { data: [] }, response_status: 200)

      expect(search.payload).to be_nil
    end

    it 'records a terminal failure' do
      search.claim
      search.finish(result: { errors: [{ title: 'Search failed' }] }, response_status: 500)

      expect(search.payload).to include('status' => 'failed', 'response_status' => 500)
    end
  end
end
