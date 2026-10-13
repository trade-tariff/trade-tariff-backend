# frozen_string_literal: true

module Search
  # Publishes immutable search vocabulary generations to Sidekiq Redis.
  #
  # The publisher runs outside search requests, through the scheduled
  # PublishSearchVocabularyWorker or the search_vocabulary rake task. It
  # captures the service, effective date and source configuration once at
  # the start, then streams eligible searchable goods sources in bounded
  # pages, tokenizing and adding words to one unique staging generation key.
  # The full word set is never held in process memory: words are added in
  # bounded batches, and the expected word count is accumulated
  # independently from the insertion count of each staged batch.
  #
  # A generation becomes visible only through one atomic Redis operation
  # that validates the staged word count, writes the manifest, records the
  # generation in the registry and switches the current pointer. The
  # previous complete generation stays readable throughout the refresh.
  # Interrupted staging generations and old published generations are
  # bounded by expiry and registry cleanup.
  #
  # Lexical membership does not establish phrase relevance or legal
  # classification correctness. The vocabulary only records which words are
  # present in the eligible searchable content.
  class ExpansionVocabularyPublisher
    PAGE_SIZE = 1_000
    SADD_BATCH = 500
    STAGING_TTL_SECONDS = 2.hours.to_i
    RETENTION_TTL_SECONDS = 7.days.to_i
    LEASE_TTL_SECONDS = 5.minutes.to_i
    BUILD_BUDGET_SECONDS = 2.hours.to_i
    RETAINED_GENERATIONS = 2

    # One atomic publication: verify this build still owns the publish
    # lease and the staged set is intact, write the manifest hash, register
    # the generation, and switch the current pointer. All writes use the
    # retention lifetime, so the pointer, manifest, registry and words set
    # expire together and no date or profile namespace leaves a permanent
    # registry. Returns 1 on success, 0 when the lease is lost, and -1 when
    # the staged set is not intact.
    PUBLISH_SCRIPT = <<~LUA
      if redis.call('GET', KEYS[5]) ~= ARGV[10] then
        return 0
      end
      if redis.call('SCARD', KEYS[1]) ~= tonumber(ARGV[1]) then
        return -1
      end
      redis.call('HSET', KEYS[2],
        'id', ARGV[5],
        'built_at', ARGV[2],
        'word_count', ARGV[1],
        'source_profile', ARGV[6],
        'service', ARGV[7],
        'date', ARGV[8],
        'normalization_version', ARGV[9])
      redis.call('EXPIRE', KEYS[2], tonumber(ARGV[4]))
      redis.call('ZADD', KEYS[3], ARGV[3], ARGV[5])
      redis.call('EXPIRE', KEYS[3], tonumber(ARGV[4]))
      redis.call('SET', KEYS[4], ARGV[5], 'EX', tonumber(ARGV[4]))
      redis.call('EXPIRE', KEYS[1], tonumber(ARGV[4]))
      return 1
    LUA

    RELEASE_LOCK_SCRIPT = <<~LUA
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('DEL', KEYS[1])
      end
      return 0
    LUA

    RENEW_LOCK_SCRIPT = <<~LUA
      if redis.call('GET', KEYS[1]) == ARGV[1] then
        return redis.call('EXPIRE', KEYS[1], tonumber(ARGV[2]))
      end
      return 0
    LUA

    # One atomic staging write: adds one bounded batch of words and renews
    # the staging expiry in the same operation. A killed publisher cannot
    # leave an unregistered staging key without a lifetime. Returns the
    # number of members the SADD inserted.
    STAGING_SADD_SCRIPT = <<~LUA
      local added = redis.call('SADD', KEYS[1], unpack(ARGV, 2))
      redis.call('EXPIRE', KEYS[1], tonumber(ARGV[1]))
      return added
    LUA

    Result = Data.define(:status, :generation, :word_count, :reason) do
      def published?
        status == :published
      end
    end

    # Token ownership lease on Sidekiq Redis, renewed as bounded batches
    # complete. A lease that expires or is lost aborts the build safely.
    class Lease
      def initialize(key, token: SecureRandom.hex(8), ttl_seconds: LEASE_TTL_SECONDS)
        @key = key
        @token = token
        @ttl_seconds = ttl_seconds
      end

      attr_reader :key, :token

      def acquire
        Sidekiq.redis do |redis|
          redis.call('SET', key, token, 'NX', 'EX', ttl_seconds) == 'OK'
        end
      end

      def renew
        Sidekiq.redis do |redis|
          redis.call('EVAL', RENEW_LOCK_SCRIPT, 1, key, token, ttl_seconds).to_i == 1
        end
      end

      def release
        Sidekiq.redis do |redis|
          redis.call('EVAL', RELEASE_LOCK_SCRIPT, 1, key, token)
        end
      end

    private

      attr_reader :ttl_seconds
    end

    class BuildAborted < StandardError; end

    class << self
      # Publishes one generation for the service. date: overrides the
      # effective date for initial publication or backfill; the source
      # configuration is captured once at the start.
      def call(date: nil)
        new(date:).call
      end
    end

    def initialize(date:)
      @service = TradeTariffBackend.service
      @date = date || Date.current
      @atar_terms = AdminConfiguration.enabled?('search_atars_enabled')
      @profile = Search::ExpansionVocabulary.source_profile(atar_enabled: @atar_terms)
      @namespace = "#{Search::ExpansionVocabulary::KEY_PREFIX}/#{@service}/#{@date}/#{@profile}"
      @generation = SecureRandom.hex(8)
      @batch = []
      @staged_word_count = 0
      @published = false
      @word_count = nil
    end

    attr_reader :service, :date, :profile, :generation

    def call
      @lease = Lease.new("#{Search::ExpansionVocabulary::KEY_PREFIX}/#{service}/publish_lock")
      return skipped('publish lock held by another publisher') unless @lease.acquire

      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        with_reader { each_source_text { |text| add_text(text) } }
        publish_generation
        published_result
      rescue BuildAborted => e
        aborted_result(e.message)
      rescue StandardError => e
        Rails.logger.warn("Search expansion vocabulary publish failed: #{e.class} #{e.message}")
        failed_result("#{e.class}: #{e.message}")
      ensure
        @lease&.release
        delete_staging unless @published
      end
    end

  private

    attr_reader :namespace

    def published_result
      Result.new(status: :published, generation:, word_count: @word_count, reason: nil)
    end

    def aborted_result(reason)
      Result.new(status: :aborted, generation: nil, word_count: nil, reason:)
    end

    def failed_result(reason)
      Result.new(status: :failed, generation: nil, word_count: nil, reason:)
    end

    def skipped(reason)
      Result.new(status: :skipped, generation: nil, word_count: nil, reason:)
    end

    # Streaming sources. Eligible content matches what search exposes: the
    # generated self-text, current goods descriptions, public search
    # references, label text, and current ATAR terms when enabled.
    def each_source_text(&block)
      return enum_for(:each_source_text) unless block_given?

      each_self_text(&block)
      each_description(&block)
      each_reference_title(&block)
      each_label_text(&block)
      each_atar_text(&block) if atar_source?
      flush_batch
    end

    def each_self_text
      each_page(self_text_dataset, :goods_nomenclature_sid) do |row|
        yield(row[:self_text])
      end
    end

    def self_text_dataset
      db[:goods_nomenclature_self_texts]
        .where(expired: false)
        .select(:goods_nomenclature_sid, :self_text)
        .order(:goods_nomenclature_sid)
    end

    def each_description
      last_sid = 0
      last_period_sid = 0

      loop do
        rows = db.fetch(description_page_sql, date, date, last_sid, last_period_sid).all
        break if rows.empty?

        rows.each { |row| yield(row[:description]) }
        heartbeat
        break if rows.size < PAGE_SIZE

        last = rows.last
        last_sid = last[:goods_nomenclature_sid]
        last_period_sid = last[:goods_nomenclature_description_period_sid]
      end
    end

    def description_page_sql
      <<~SQL
        SELECT d.description,
               d.goods_nomenclature_sid,
               d.goods_nomenclature_description_period_sid
        FROM goods_nomenclature_descriptions d
        JOIN goods_nomenclature_description_periods p
          ON p.goods_nomenclature_description_period_sid = d.goods_nomenclature_description_period_sid
         AND p.goods_nomenclature_sid = d.goods_nomenclature_sid
        WHERE d.description IS NOT NULL
          AND p.validity_start_date <= ?
          AND (p.validity_end_date >= ? OR p.validity_end_date IS NULL)
          AND (d.goods_nomenclature_sid, d.goods_nomenclature_description_period_sid) > (?, ?)
        ORDER BY d.goods_nomenclature_sid, d.goods_nomenclature_description_period_sid
        LIMIT #{PAGE_SIZE}
      SQL
    end

    def each_reference_title
      dataset = db[:search_references].where(usage: 'search').exclude(title: nil)
                         .select(:id, :title).order(:id)
      each_page(dataset, :id) do |row|
        yield(row[:title])
      end
    end

    def each_label_text(&block)
      dataset = db[:goods_nomenclature_labels].where(expired: false)
                         .select(:goods_nomenclature_sid, :description, :synonyms,
                                 :colloquial_terms, :known_brands)
                         .order(:goods_nomenclature_sid)
      each_page(dataset, :goods_nomenclature_sid) do |row|
        yield(row[:description])
        Array(row[:synonyms]).each(&block)
        Array(row[:colloquial_terms]).each(&block)
        Array(row[:known_brands]).each(&block)
      end
    end

    def each_atar_text(&block)
      each_page(atar_rulings_dataset, :id) do |row|
        Array(row[:keywords]).each(&block)
        Array(row[:derived_facts]).each(&block)
      end
    end

    def atar_rulings_dataset
      db[:tariff_knowledge_public_atar_rulings]
        .where(Sequel[:validity_start_date] <= date)
        .where(Sequel.lit('validity_end_date >= ? OR validity_end_date IS NULL', date))
        .select(:id, :keywords, :derived_facts)
        .order(:id)
    end

    def atar_source?
      profile.include?('atar')
    end

    def each_page(dataset, order_key, &block)
      last = nil

      loop do
        page = dataset
        page = page.where(Sequel[order_key] > last) if last
        rows = page.limit(PAGE_SIZE).all
        break if rows.empty?

        rows.each(&block)
        heartbeat
        break if rows.size < PAGE_SIZE

        last = rows.last[order_key]
      end
    end

    def db
      Sequel::Model.db
    end

    # Reads through the read-replica when one is configured, so the build
    # does not take pages from the primary.
    def with_reader(&block)
      database = Sequel::Model.db
      if database.servers.include?(:reader)
        database.with_server(:reader, &block)
      else
        yield
      end
    end

    # Incremental tokenization into the staging generation. Bounded batches
    # are added to Redis immediately; no local copy of the word set exists.
    def add_text(text)
      words = Search::ExpansionVocabulary.extract_words(text)
      return if words.empty?

      @batch.concat(words)
      flush_batch if @batch.size >= SADD_BATCH
    end

    def flush_batch
      return if @batch.empty?

      added = Sidekiq.redis do |redis|
        redis.call('EVAL', STAGING_SADD_SCRIPT, 1, words_key,
                   STAGING_TTL_SECONDS, *@batch.uniq)
      end
      # The expected word count is derived independently from the insertion
      # counts of the staged batches, never from the set itself.
      @staged_word_count += added.to_i
      @batch.clear
    end

    def cleanup_guard
      yield
    rescue StandardError => e
      Rails.logger.warn("Search expansion vocabulary cleanup failed: #{e.class} #{e.message}")
    end

    def publish_generation
      flush_batch
      heartbeat
      # The staged set must match the independently accumulated count. A
      # set that lost members between batches, or was deleted or evicted
      # before publication, aborts instead of certifying a partial corpus.
      staged_count = Sidekiq.redis { |redis| redis.call('SCARD', words_key).to_i }
      unless staged_count == @staged_word_count
        raise BuildAborted, 'staged word set was not intact at publication'
      end

      word_count = @staged_word_count
      built_at = Time.current.utc.iso8601

      reply = Sidekiq.redis do |redis|
        redis.call(
          'EVAL', PUBLISH_SCRIPT, 5,
          words_key, manifest_key, registry_key, current_key, @lease.key,
          word_count, built_at, Time.current.utc.to_f, RETENTION_TTL_SECONDS, generation,
          profile, service, date.iso8601, Search::ExpansionVocabulary::NORMALIZATION_VERSION,
          @lease.token
        ).to_i
      end
      raise BuildAborted, 'publish lease lost' if reply.zero?
      raise BuildAborted, 'staged word set was not intact at publication' unless reply == 1

      @published = true
      @word_count = word_count
      cleanup_guard { cleanup_old_generations }
    end

    # Keeps the newest complete generations and removes older ones. The
    # current and previous generations remain readable across a refresh.
    # The reply is flattened because WITHSCORES returns member/score pairs
    # as nested arrays in Redis protocol 3.
    def cleanup_old_generations
      Sidekiq.redis do |redis|
        members = redis.call('ZRANGE', registry_key, 0, -1, 'WITHSCORES').flatten
        entries = members.each_slice(2).to_a
        keep = entries.sort_by { |_, score| score.to_f }.last(RETAINED_GENERATIONS).map(&:first)
        (entries.map(&:first) - keep).each do |old_id|
          redis.call('DEL', generation_words_key(old_id), generation_manifest_key(old_id))
          redis.call('ZREM', registry_key, old_id)
        end
      end
    end

    def delete_staging
      Sidekiq.redis { |redis| redis.call('DEL', words_key) }
    rescue StandardError => e
      Rails.logger.warn("Search expansion vocabulary staging cleanup failed: #{e.class} #{e.message}")
    end

    # Bounds the build: the lease is renewed as each page completes, and a
    # build that exceeds its budget or loses the lease is aborted.
    def heartbeat
      raise BuildAborted, 'build budget exceeded' if elapsed_seconds > BUILD_BUDGET_SECONDS
      raise BuildAborted, 'publish lease lost' unless @lease&.renew
    end

    def elapsed_seconds
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at
    end

    def current_key
      "#{namespace}/current"
    end

    def registry_key
      "#{namespace}/generations"
    end

    def words_key
      generation_words_key(generation)
    end

    def manifest_key
      generation_manifest_key(generation)
    end

    def generation_words_key(id)
      "#{namespace}/g:#{id}:words"
    end

    def generation_manifest_key(id)
      "#{namespace}/g:#{id}:manifest"
    end
  end
end
