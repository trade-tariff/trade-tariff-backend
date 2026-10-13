# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::ExpansionVocabulary do
  before do
    described_class.reset!
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)
    clear_vocabulary_keys
  end

  after do
    clear_vocabulary_keys
    described_class.reset!
  end

  def clear_vocabulary_keys
    Sidekiq.redis do |redis|
      keys = redis.call('KEYS', "#{described_class::KEY_PREFIX}/*")
      redis.call('DEL', *keys) unless keys.empty?
    end
  end

  def namespace(profile: described_class.source_profile(atar_enabled: false),
                service: TradeTariffBackend.service,
                date: Date.current)
    "#{described_class::KEY_PREFIX}/#{service}/#{date}/#{profile}"
  end

  # Hand-publishes a generation with the same layout the publisher writes.
  def publish_generation(id:, words:, profile: described_class.source_profile(atar_enabled: false),
                         service: TradeTariffBackend.service, date: Date.current)
    ns = namespace(profile:, service:, date:)
    Sidekiq.redis do |redis|
      redis.call('SADD', "#{ns}/g:#{id}:words", *words) unless words.empty?
      redis.call('HSET', "#{ns}/g:#{id}:manifest",
                 'id', id,
                 'built_at', Time.current.utc.iso8601,
                 'word_count', words.size,
                 'source_profile', profile,
                 'service', service,
                 'date', date.iso8601,
                 'normalization_version', described_class::NORMALIZATION_VERSION)
      redis.call('SET', "#{ns}/current", id)
    end
    id
  end

  describe '.extract_words' do
    it 'downcases and splits on characters outside words' do
      expect(described_class.extract_words('Fresh Poultry, carcasses')).to eq(%w[fresh poultry carcasses])
    end

    it 'keeps apostrophes inside words' do
      expect(described_class.extract_words("women's dresses")).to eq(%w[women's dresses])
    end

    it 'drops words without an alphanumeric character' do
      expect(described_class.extract_words("' - '")).to eq([])
    end
  end

  describe '.strip_surrounding_quotes' do
    it 'removes a leading or trailing quote without touching an inner apostrophe' do
      expect(described_class.strip_surrounding_quotes(%q("women's))).to eq("women's")
      expect(described_class.strip_surrounding_quotes("trout'")).to eq('trout')
    end
  end

  describe '.source_profile' do
    it 'lists the eligible searchable sources' do
      expect(described_class.source_profile(atar_enabled: false))
        .to eq('self_text+descriptions+references+labels')
    end

    it 'adds the ATAR source only when ATAR terms are enabled' do
      expect(described_class.source_profile(atar_enabled: true))
        .to eq('self_text+descriptions+references+labels+atar')
    end
  end

  describe '.lookup' do
    it 'returns the supported subset of the current generation' do
      generation = publish_generation(id: 'gen1', words: %w[poultry carcasses])

      lookup = described_class.lookup(%w[poultry zaptoxidinyl])

      expect(lookup).to be_ready
      expect(lookup.words).to eq(Set['poultry'])
      expect(lookup.generation).to eq(generation)
    end

    it 'is ready with no words when the generation has no matching candidates' do
      publish_generation(id: 'gen1', words: %w[poultry])

      lookup = described_class.lookup(%w[zaptoxidinyl])

      expect(lookup).to be_ready
      expect(lookup.words).to be_empty
      expect(lookup.generation).to eq('gen1')
    end

    it 'checks readiness for an empty candidate list' do
      publish_generation(id: 'gen1', words: %w[poultry])

      lookup = described_class.lookup([])

      expect(lookup).to be_ready
      expect(lookup.words).to be_empty
      expect(lookup.generation).to eq('gen1')
    end

    it 'is ready for an explicitly published empty corpus' do
      publish_generation(id: 'gen1', words: [])

      lookup = described_class.lookup(%w[poultry])

      expect(lookup).to be_ready
      expect(lookup.words).to be_empty
      expect(lookup.generation).to eq('gen1')
    end

    it 'is unavailable when no generation is published' do
      lookup = described_class.lookup(%w[poultry])

      expect(lookup).not_to be_ready
      expect(lookup.words).to be_empty
      expect(lookup.generation).to be_nil
    end

    it 'is unavailable when the manifest is missing for the current generation' do
      publish_generation(id: 'gen1', words: %w[poultry])
      Sidekiq.redis { |redis| redis.call('DEL', "#{namespace}/g:gen1:manifest") }

      lookup = described_class.lookup(%w[poultry])

      expect(lookup).not_to be_ready
      expect(lookup.generation).to be_nil
    end

    it 'is unavailable when the words set is missing behind a non-zero word count' do
      publish_generation(id: 'gen1', words: %w[poultry])
      Sidekiq.redis { |redis| redis.call('DEL', "#{namespace}/g:gen1:words") }

      lookup = described_class.lookup(%w[poultry])

      expect(lookup).not_to be_ready
      expect(lookup.generation).to be_nil
    end

    it 'is unavailable when the words set no longer matches the manifest word count' do
      publish_generation(id: 'gen1', words: %w[poultry])
      Sidekiq.redis do |redis|
        redis.call('SADD', "#{namespace}/g:gen1:words", 'extra')
      end

      lookup = described_class.lookup(%w[poultry])

      expect(lookup).not_to be_ready
      expect(lookup.generation).to be_nil
    end

    it 'pins one generation so availability and words cannot come from different generations' do
      publish_generation(id: 'gen1', words: %w[poultry])
      publish_generation(id: 'gen2', words: %w[carcasses])

      lookup = described_class.lookup(%w[poultry carcasses])

      expect(lookup.generation).to eq('gen2')
      expect(lookup.words).to eq(Set['carcasses'])
    end

    it 'uses the ATAR source profile only when ATAR terms are enabled' do
      allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(true)
      atar_profile = described_class.source_profile(atar_enabled: true)
      publish_generation(id: 'gen1', words: %w[ceiling], profile: atar_profile)

      expect(described_class.lookup(%w[ceiling])).to be_ready

      allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)

      expect(described_class.lookup(%w[ceiling])).not_to be_ready
    end

    it 'uses the time machine date when one is set' do
      other_date = Date.current - 1
      allow(TradeTariffRequest).to receive(:time_machine_now)
        .and_return(other_date.beginning_of_day)
      publish_generation(id: 'gen1', words: %w[poultry], date: other_date)

      expect(described_class.lookup(%w[poultry])).to be_ready
    end

    it 'is unavailable for a date with no published generation' do
      allow(TradeTariffRequest).to receive(:time_machine_now)
        .and_return((Date.current - 30).beginning_of_day)

      expect(described_class.lookup(%w[poultry])).not_to be_ready
    end

    it 'returns unavailable instead of raising when the pool wait times out' do
      pool = Object.new
      allow(pool).to receive(:with).and_raise(ConnectionPool::TimeoutError)
      allow(described_class).to receive(:lookup_pool).and_return(pool)

      lookup = described_class.lookup(%w[poultry])

      expect(lookup).not_to be_ready
      expect(lookup.generation).to be_nil
    end

    it 'returns unavailable instead of raising on a Redis connection error' do
      pool = Object.new
      allow(pool).to receive(:with).and_raise(RedisClient::ConnectionError, 'connection lost')
      allow(described_class).to receive(:lookup_pool).and_return(pool)

      lookup = described_class.lookup(%w[poultry])

      expect(lookup).not_to be_ready
      expect(lookup.generation).to be_nil
    end
  end

  describe 'lookup connection budget' do
    it 'targets the same Sidekiq Redis endpoint with bounded timeouts and no reconnects' do
      config = described_class.send(:pool_client_config)
      sidekiq_config = TradeTariffBackend.sidekiq_redis_config

      expect(config[:url]).to eq(sidekiq_config[:url])
      expect(config[:db]).to eq(sidekiq_config[:db])
      expect(config[:timeout]).to eq(0.05)
      expect(config[:read_timeout]).to eq(0.05)
      expect(config[:write_timeout]).to eq(0.05)
      expect(config[:connect_timeout]).to eq(0.05)
      expect(config[:reconnect_attempts]).to eq(0)
    end

    it 'uses a small pool with a bounded checkout wait' do
      expect(described_class::POOL_SIZE).to eq(2)
      expect(described_class::POOL_WAIT_SECONDS).to eq(0.05)
    end
  end
end
