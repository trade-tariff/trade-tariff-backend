# frozen_string_literal: true

module Search
  # Bounded membership lookup against a published search vocabulary.
  #
  # The vocabulary is a versioned derived search index, published to Sidekiq
  # Redis by Search::ExpansionVocabularyPublisher. It is never built or
  # refreshed inside a search request or a queued-search worker. A lookup
  # reads one published generation atomically and checks only the candidate
  # words. Web requests and queued searches use this same path.
  #
  # No vocabulary data is retained in this class or in process memory. The
  # only retained state is a small dedicated connection pool for the
  # optional membership check.
  #
  # Readiness is explicit. A published generation with no matching candidate
  # words is ready. A missing generation, a wrong-date generation, a Redis
  # error or a pool wait timeout is unavailable. The caller keeps the
  # original query when the vocabulary is unavailable.
  #
  # Membership is lexical evidence only: it cannot establish phrase relevance
  # or legal classification correctness.
  class ExpansionVocabulary
    # Bump when the published word normalization changes.
    NORMALIZATION_VERSION = 'n1'
    KEY_PREFIX = "search_vocabulary/#{NORMALIZATION_VERSION}".freeze
    WORD_PATTERN = /[\p{alnum}']+/
    OPENING_QUOTE_PATTERN = /(?<![\p{alnum}'"])["'](?=\p{alnum})/
    CLOSING_QUOTE_PATTERN = /(?<=\p{alnum})["'](?![\p{alnum}'"])/

    # Optional-check I/O budget. POOL_WAIT bounds how long a lookup waits
    # for a pooled connection. IO_TIMEOUT bounds the connect and socket
    # timeouts of that dedicated connection, and no reconnect is attempted.
    # Each timeout bounds one pool checkout or one socket operation; they do
    # not imply a full end-to-end deadline for the whole search operation.
    POOL_SIZE = 2
    POOL_WAIT_SECONDS = 0.05
    IO_TIMEOUT_SECONDS = 0.05

    # One atomic read: resolve the current generation, confirm its manifest
    # exists and its words set is intact against the manifest word count,
    # then test each candidate word against that same generation. An
    # explicitly published empty corpus has a word count of zero and an
    # absent words set, which is ready; a missing words set behind a
    # non-zero count is unavailable.
    LOOKUP_SCRIPT = <<~LUA
      local generation = redis.call('GET', KEYS[1])
      if not generation then
        return {0}
      end
      local manifest_key = KEYS[2] .. generation .. ':manifest'
      local words_key = KEYS[2] .. generation .. ':words'
      local word_count = redis.call('HGET', manifest_key, 'word_count')
      if not word_count then
        return {0}
      end
      if tonumber(word_count) ~= redis.call('SCARD', words_key) then
        return {0}
      end
      local hits = {}
      for i = 1, #ARGV do
        hits[i] = redis.call('SISMEMBER', words_key, ARGV[i])
      end
      return {1, generation, hits}
    LUA

    Lookup = Data.define(:status, :words, :generation) do
      def ready?
        status == :ready
      end
    end

    class << self
      def extract_words(text)
        text.to_s.downcase.scan(WORD_PATTERN)
            .map { |word| strip_surrounding_quotes(word) }
            .select { |word| word.match?(/\p{alnum}/) }
      end

      def strip_surrounding_quotes(text)
        text.to_s.gsub(OPENING_QUOTE_PATTERN, '').gsub(CLOSING_QUOTE_PATTERN, '')
      end

      # Checks the candidate words against the current published generation.
      # Availability and words always come from that single generation.
      # Returns a Lookup value: :ready with the supported subset, or
      # :unavailable with no words. Never raises on Redis or pool failures.
      def lookup(candidates)
        words = candidates.grep(String).map(&:to_s).uniq
        service, date, profile = default_context

        ready, generation, hits = read_generation(service:, date:, profile:, candidates: words)
        return unavailable unless ready == 1 && generation.is_a?(String)

        Lookup.new(
          status: :ready,
          words: words.zip(hits || []).select { |_, hit| hit.to_i == 1 }.map(&:first).to_set,
          generation:,
        )
      rescue RedisClient::Error, ConnectionPool::Error, ConnectionPool::TimeoutError
        unavailable
      end

      # Source profile shared with the publisher: the union of eligible
      # searchable goods sources. ATAR terms are included only when the
      # search ATAR flag is enabled.
      def source_profile(atar_enabled: atar_terms_enabled?)
        profile = %w[self_text descriptions references labels]
        profile << 'atar' if atar_enabled
        profile.join('+')
      end

      # Drops the memoized lookup connection pool. Test support only.
      def reset!
        @lookup_pool = nil
      end

    private

      def unavailable
        Lookup.new(status: :unavailable, words: Set.new, generation: nil)
      end

      def read_generation(service:, date:, profile:, candidates:)
        namespace = "#{KEY_PREFIX}/#{service}/#{date}/#{profile}"
        lookup_pool.with do |client|
          client.call('EVAL', LOOKUP_SCRIPT, 2,
                      "#{namespace}/current", "#{namespace}/g:", *candidates)
        end
      end

      def lookup_pool
        @lookup_pool ||= ConnectionPool.new(size: POOL_SIZE, timeout: POOL_WAIT_SECONDS) do
          RedisClient.new(**pool_client_config)
        end
      end

      # Same Sidekiq Redis endpoint and database as the application, but with
      # bounded optional-check timeouts and no reconnects. This pool is not a
      # vocabulary cache: it holds connections only.
      def pool_client_config
        config = TradeTariffBackend.sidekiq_redis_config
        {
          url: config[:url],
          db: config[:db] || 0,
          timeout: IO_TIMEOUT_SECONDS,
          read_timeout: IO_TIMEOUT_SECONDS,
          write_timeout: IO_TIMEOUT_SECONDS,
          connect_timeout: IO_TIMEOUT_SECONDS,
          reconnect_attempts: 0,
        }
      end

      def default_context
        [
          TradeTariffBackend.service,
          TradeTariffRequest.time_machine_now&.to_date || Date.current,
          source_profile,
        ]
      end

      def atar_terms_enabled?
        AdminConfiguration.enabled?('search_atars_enabled')
      end
    end
  end
end
