# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Search::ExpansionVocabularyPublisher do
  before do
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(false)
    clear_vocabulary_keys
  end

  after { clear_vocabulary_keys }

  def clear_vocabulary_keys
    Sidekiq.redis do |redis|
      keys = redis.call('KEYS', "#{Search::ExpansionVocabulary::KEY_PREFIX}/*")
      redis.call('DEL', *keys) unless keys.empty?
    end
  end

  def namespace(date: Date.current, profile: Search::ExpansionVocabulary.source_profile(atar_enabled: false))
    "#{Search::ExpansionVocabulary::KEY_PREFIX}/#{TradeTariffBackend.service}/#{date}/#{profile}"
  end

  def publisher(date: Date.current)
    described_class.new(date:)
  end

  def publish_with_words(*words, date: Date.current)
    instance = publisher(date:)
    allow(instance).to receive(:each_source_text) do |&block|
      words.each { |word| block.call(word) }
    end

    instance.call
  end

  def current_id(date: Date.current)
    Sidekiq.redis { |redis| redis.call('GET', "#{namespace(date:)}/current") }
  end

  def manifest(id:, date: Date.current)
    Sidekiq.redis { |redis| redis.call('HGETALL', "#{namespace(date:)}/g:#{id}:manifest") }
  end

  def scard(id:, date: Date.current)
    Sidekiq.redis { |redis| redis.call('SCARD', "#{namespace(date:)}/g:#{id}:words") }
  end

  def word_set_keys(date: Date.current)
    Sidekiq.redis { |redis| redis.call('KEYS', "#{namespace(date:)}/g:*:words") }
  end

  describe '#call' do
    it 'publishes a complete generation from the eligible sources' do
      create(:goods_nomenclature_self_text, self_text: 'Fresh poultry carcasses')
      create(:goods_nomenclature_self_text, :expired, self_text: 'Obsolete zaptoxidinyl serum')
      create(:goods_nomenclature_description, description: 'Live bovine animals')
      create(:goods_nomenclature_description, description: 'Historic ambergris', validity_end_date: 1.day.ago)
      create(:goods_nomenclature_label, :with_labels)
      create(:goods_nomenclature_label, :expired)
      create(:search_reference, title: 'Turkey meat cuts')
      create(:search_reference, title: 'Frontier passport office', usage: 'fpo')

      result = publisher.call

      expect(result).to be_published
      expect(result.word_count).to be_positive

      words = Sidekiq.redis do |redis|
        redis.call('SMEMBERS', "#{namespace}/g:#{result.generation}:words")
      end
      expect(words).to include('poultry', 'carcasses', 'bovine', 'honey', 'turkey')
      expect(words).not_to include('zaptoxidinyl', 'ambergris', 'passport', 'flibble')

      expect(current_id).to eq(result.generation)
      expect(scard(id: result.generation)).to eq(result.word_count)
    end

    it 'includes current ATAR terms only when the profile enables them' do
      create(:tariff_knowledge_public_atar_ruling,
             keywords: Sequel.pg_array(['CEILING LIGHTS'], :text),
             derived_facts: Sequel.pg_array(['OF GLASS'], :text),
             validity_start_date: Date.current - 1.year,
             validity_end_date: Date.current + 1.year)

      result = publisher.call
      atar_words = Sidekiq.redis do |redis|
        redis.call('SMEMBERS', "#{namespace}/g:#{result.generation}:words")
      end
      expect(atar_words).not_to include('ceiling', 'glass')

      allow(AdminConfiguration).to receive(:enabled?).with('search_atars_enabled').and_return(true)

      atar_result = described_class.new(date: Date.current).call
      atar_namespace = namespace(profile: Search::ExpansionVocabulary.source_profile(atar_enabled: true))
      words_with_atar = Sidekiq.redis do |redis|
        redis.call('SMEMBERS', "#{atar_namespace}/g:#{atar_result.generation}:words")
      end
      expect(words_with_atar).to include('ceiling', 'lights', 'glass')
    end

    it 'writes the manifest with the generation identity and source profile' do
      result = publish_with_words('fresh poultry')

      expect(result.word_count).to eq(2)
      expect(manifest(id: result.generation)).to include(
        'id' => result.generation,
        'word_count' => '2',
        'source_profile' => 'self_text+descriptions+references+labels',
        'service' => TradeTariffBackend.service,
        'date' => Date.current.iso8601,
        'normalization_version' => Search::ExpansionVocabulary::NORMALIZATION_VERSION,
      )
      expect(manifest(id: result.generation)['built_at']).to be_present
    end

    it 'publishes an explicitly empty corpus that is ready for lookups' do
      result = publish_with_words

      expect(result).to be_published
      expect(result.word_count).to eq(0)
      expect(word_set_keys).to be_empty
      expect(current_id).to eq(result.generation)

      lookup = Search::ExpansionVocabulary.lookup(%w[poultry])
      expect(lookup).to be_ready
      expect(lookup.words).to be_empty
    end

    it 'keeps the previous generation readable while publishing a new one' do
      first = publish_with_words('fresh poultry')
      second = publish_with_words('frozen beef')

      expect(current_id).to eq(second.generation)
      expect(scard(id: first.generation)).to eq(2)
      expect(manifest(id: first.generation)).to include('id' => first.generation)

      lookup = Search::ExpansionVocabulary.lookup(%w[fresh frozen beef])
      expect(lookup.generation).to eq(second.generation)
      expect(lookup.words).to eq(Set['frozen', 'beef'])
    end

    it 'removes generations older than the retained pair' do
      first = publish_with_words('fresh')
      second = publish_with_words('frozen')
      third = publish_with_words('smoked')

      expect(current_id).to eq(third.generation)
      expect(manifest(id: second.generation)).to be_present
      expect(word_set_keys).to contain_exactly(
        "#{namespace}/g:#{second.generation}:words",
        "#{namespace}/g:#{third.generation}:words",
      )
      expect(manifest(id: first.generation)).to be_empty
    end

    it 'bounds the lifetime of the published keys' do
      result = publish_with_words('fresh poultry')

      Sidekiq.redis do |redis|
        ns = namespace
        expect(redis.call('TTL', "#{ns}/g:#{result.generation}:words")).to be_positive
        expect(redis.call('TTL', "#{ns}/g:#{result.generation}:manifest")).to be_positive
        expect(redis.call('TTL', "#{ns}/generations")).to be_positive
        expect(redis.call('TTL', "#{ns}/current")).to be_positive
      end
    end

    it 'skips publication while another publisher holds the lock' do
      lock_key = "#{Search::ExpansionVocabulary::KEY_PREFIX}/#{TradeTariffBackend.service}/publish_lock"
      Sidekiq.redis { |redis| redis.call('SET', lock_key, 'other-token', 'NX', 'EX', 60) }

      result = publisher.call

      expect(result.status).to eq(:skipped)
      expect(result).not_to be_published
      expect(current_id).to be_nil
    end

    it 'releases the publish lock when it completes' do
      lock_key = "#{Search::ExpansionVocabulary::KEY_PREFIX}/#{TradeTariffBackend.service}/publish_lock"

      publish_with_words('fresh poultry')

      expect(Sidekiq.redis { |redis| redis.call('EXISTS', lock_key) }).to eq(0)
    end

    it 'aborts when the publish lease is lost before the pointer switch' do
      previous = publish_with_words('fresh poultry')
      lock_key = "#{Search::ExpansionVocabulary::KEY_PREFIX}/#{TradeTariffBackend.service}/publish_lock"

      instance = publisher
      allow(instance).to receive(:each_source_text).and_yield('frozen beef')
      # A foreign writer replaces the lease token immediately before publication.
      allow(instance).to receive(:heartbeat) do
        Sidekiq.redis { |redis| redis.call('SET', lock_key, 'foreign-token') }
      end

      result = instance.call

      expect(result.status).to eq(:aborted)
      expect(result.reason).to eq('publish lease lost')
      expect(current_id).to eq(previous.generation)
      expect(scard(id: previous.generation)).to eq(2)
      expect(manifest(id: instance.generation)).to be_empty
      # Without ownership we leave staging to its bounded expiry, rather
      # than risking deletion after an ambiguous publication outcome.
      Sidekiq.redis do |redis|
        expect(redis.call('GET', lock_key)).to eq('foreign-token')
        expect(redis.call('TTL', "#{namespace}/g:#{instance.generation}:words"))
          .to be_between(1, described_class::STAGING_TTL_SECONDS)
      end
    end

    it 'aborts when the staged word set loses members before publication' do
      instance = publisher
      allow(instance).to receive(:each_source_text).and_yield('fresh poultry')
      staging_words_key = "#{namespace}/g:#{instance.generation}:words"
      allow(instance).to receive(:heartbeat) do
        # Evict part of the staged set immediately before publication.
        Sidekiq.redis { |redis| redis.call('SREM', staging_words_key, 'poultry') }
      end

      result = instance.call

      expect(result.status).to eq(:aborted)
      expect(result.reason).to eq('staged word set was not intact at publication')
      expect(current_id).to be_nil
      expect(word_set_keys).to be_empty
    end

    it 'aborts when the staged word set is deleted before publication' do
      instance = publisher
      allow(instance).to receive(:each_source_text).and_yield('fresh poultry')
      staging_words_key = "#{namespace}/g:#{instance.generation}:words"
      allow(instance).to receive(:heartbeat) do
        Sidekiq.redis { |redis| redis.call('DEL', staging_words_key) }
      end

      result = instance.call

      expect(result.status).to eq(:aborted)
      expect(result.reason).to eq('staged word set was not intact at publication')
      expect(current_id).to be_nil
    end

    it 'leaves an abandoned staging key with a bounded atomic expiry' do
      instance = publisher
      allow(instance).to receive(:each_source_text).and_yield('fresh poultry')
      allow(instance).to receive(:heartbeat)
        .and_raise(described_class::BuildAborted, 'publish lease lost')
      # A killed process cannot run the staging cleanup; the key must still
      # carry the lifetime written atomically with its words.
      allow(instance).to receive(:delete_staging)

      result = instance.call

      expect(result.status).to eq(:aborted)
      expect(word_set_keys).to contain_exactly("#{namespace}/g:#{instance.generation}:words")
      Sidekiq.redis do |redis|
        ttl = redis.call('TTL', "#{namespace}/g:#{instance.generation}:words")
        expect(ttl).to be_positive
        expect(ttl).to be <= described_class::STAGING_TTL_SECONDS
      end
    end

    it 'aborts when the build budget is exceeded' do
      stub_const("#{described_class}::BUILD_BUDGET_SECONDS", -1)

      result = publish_with_words('fresh poultry')

      expect(result.status).to eq(:aborted)
      expect(result.reason).to eq('build budget exceeded')
      expect(current_id).to be_nil
      expect(word_set_keys).to be_empty
    end

    it 'keeps the previous generation and removes staging when a build fails' do
      previous = publish_with_words('fresh poultry')

      instance = publisher
      allow(instance).to receive(:each_source_text).and_raise(StandardError, 'database unavailable')

      result = instance.call

      expect(result.status).to eq(:failed)
      expect(result.reason).to include('database unavailable')
      expect(current_id).to eq(previous.generation)
      expect(word_set_keys).to contain_exactly("#{namespace}/g:#{previous.generation}:words")
    end

    it 'removes uncommitted staging before releasing the lease' do
      previous = publish_with_words('fresh poultry')
      instance = publisher
      source = Array.new(described_class::SADD_BATCH) { |index| "word#{index}" }.join(' ')
      allow(instance).to receive(:each_source_text) do |&block|
        block.call(source)
        raise StandardError, 'source read failed after staging'
      end

      result = instance.call

      expect(result.status).to eq(:failed)
      expect(current_id).to eq(previous.generation)
      expect(word_set_keys).to contain_exactly("#{namespace}/g:#{previous.generation}:words")
    end

    it 'preserves publication after a lost reply', :aggregate_failures do
      instance = publisher
      allow(instance).to receive(:each_source_text).and_yield('fresh poultry')

      Sidekiq.redis do |redis|
        allow(redis).to receive(:call).and_wrap_original do |operation, *args|
          reply = operation.call(*args)
          if args.first == 'EVAL' && args[1] == described_class::PUBLISH_SCRIPT
            raise RedisClient::ReadTimeoutError, 'publication reply lost'
          end

          reply
        end

        result = instance.call

        expect(result.status).to eq(:failed)
        expect(result.reason).to include('publication reply lost')
      end

      expect(current_id).to eq(instance.generation)
      expect(scard(id: instance.generation)).to eq(2)
      lookup = Search::ExpansionVocabulary.lookup(%w[fresh poultry])
      expect(lookup).to be_ready
      expect(lookup.words).to eq(Set['fresh', 'poultry'])
    end

    it 'caps each staging batch for large texts', :aggregate_failures do
      words = Array.new(described_class::SADD_BATCH * 2 + 3) { |index| "word#{index}" }
      batches = []
      result = nil

      Sidekiq.redis do |redis|
        allow(redis).to receive(:call).and_wrap_original do |operation, *args|
          if args.first == 'EVAL' && args[1] == described_class::STAGING_SADD_SCRIPT
            batches << args.drop(5)
          end
          operation.call(*args)
        end

        result = publish_with_words('initial prefix', words.join(' '))
      end

      expect(result).to be_published
      expect(batches.map(&:size)).to eq([described_class::SADD_BATCH, described_class::SADD_BATCH, 5])
      expect(batches.flatten).to match_array(%w[initial prefix] + words)
      expect(result.word_count).to eq(words.size + 2)
    end

    it 'does not let a cleanup failure hide a completed publication' do
      instance = publisher
      allow(instance).to receive(:each_source_text).and_yield('fresh poultry')
      allow(instance).to receive(:cleanup_old_generations)
        .and_raise(StandardError, 'registry unavailable')

      result = instance.call

      expect(result).to be_published
      expect(current_id).to eq(result.generation)
    end

    it 'reads sources through the reader connection when one is configured' do
      database = Sequel::Model.db
      allow(database).to receive(:servers).and_return({ reader: {} })
      allow(database).to receive(:with_server).and_yield
      allow(Sequel::Model).to receive(:db).and_return(database)

      publish_with_words('fresh poultry')

      expect(database).to have_received(:with_server).with(:reader)
    end

    it 'publishes under the explicit backfill date' do
      backfill_date = Date.current - 7
      result = publish_with_words('historical poultry', date: backfill_date)

      expect(result).to be_published
      expect(current_id(date: backfill_date)).to eq(result.generation)
      expect(manifest(id: result.generation, date: backfill_date)['date']).to eq(backfill_date.iso8601)
    end
  end
end
