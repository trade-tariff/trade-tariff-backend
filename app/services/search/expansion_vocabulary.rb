# frozen_string_literal: true

module Search
  # In-process word set for expansion filtering.
  #
  # A search request only checks this set. It does not scan descriptions.
  # The set is built on a background thread after the first search in the
  # process, then refreshed in the background when it is stale. A cold
  # process has no set yet, so the filter keeps the original query.
  #
  # The build reads one page at a time and returns the connection after
  # each page. It does not hold a pooled connection for the whole build.
  # The pool stays sized to the process threads. A refresh page waits for
  # a free connection instead of reserving one.
  #
  # Only one snapshot is kept, for the current date and the ATaR flag.
  # A time machine request for another date does not use that snapshot and
  # does not start a rebuild. Those requests keep the original query.
  # Historical dates are rare, and a second snapshot would replace this one
  # and rebuild the whole set.
  #
  # A worker does not build or retain the set. Queued search checks only the
  # candidate words against a shared Redis set. A missing set keeps the
  # original query.
  class ExpansionVocabulary
    TTL = 1.hour
    SHARED_TTL = 26.hours
    PAGE_SIZE = 1_000
    REFRESH_JITTER_SECONDS = 3
    WORD_PATTERN = /[\p{alnum}']+/
    OPENING_QUOTE_PATTERN = /(?<![\p{alnum}'"])["'](?=\p{alnum})/
    CLOSING_QUOTE_PATTERN = /(?<=\p{alnum})["'](?![\p{alnum}'"])/
    MUTEX = Mutex.new

    Snapshot = Data.define(:key, :words, :loaded_at)

    class << self
      def extract_words(text)
        text.to_s.downcase.scan(WORD_PATTERN)
            .map { |word| strip_surrounding_quotes(word) }
            .select { |word| word.match?(/\p{alnum}/) }
      end

      def strip_surrounding_quotes(text)
        text.to_s.gsub(OPENING_QUOTE_PATTERN, '').gsub(CLOSING_QUOTE_PATTERN, '')
      end

      # Returns the subset of candidates present in the loaded set.
      # Returns nil when the set is not loaded yet. The caller keeps the
      # original query in that case.
      def supported_words(candidates)
        at, atar = context
        return nil unless current_date?(at)
        return worker_supported_words(candidates, at, atar) if worker_process?

        key = cache_key(at, atar)
        snapshot = @snapshot

        if snapshot&.key == key
          schedule_refresh(atar) if !fresh?(snapshot) && !Rails.env.test?
          schedule_shared_republish(at, atar, snapshot.words) if fresh?(snapshot) && !Rails.env.test?
          return select_supported(snapshot.words, candidates)
        end

        return select_supported(build(at, atar), candidates) if Rails.env.test?

        schedule_refresh(atar)
        nil
      end

      def remember!(words, at: vocabulary_date, atar: atar_enabled?)
        @snapshot = Snapshot.new(key: cache_key(at, atar), words: words.to_set, loaded_at: Time.current)
      end

      def reset!
        @snapshot = nil
        @refreshing = false
      end

    private

      def select_supported(words, candidates)
        candidates.select { |word| words.include?(word) }.to_set
      end

      def context
        [vocabulary_date, atar_enabled?]
      end

      def vocabulary_date
        TradeTariffRequest.time_machine_now&.to_date || Date.current
      end

      def atar_enabled?
        AdminConfiguration.enabled?('search_atars_enabled')
      end

      def current_date?(at)
        at == Date.current
      end

      SHARED_CACHE_PREFIX = 'search_expansion_vocabulary/v1'

      # Queued search runs this filter inside Sidekiq. Read the shared cache
      # only. Do not build or retain the set in the worker.
      def worker_process?
        Sidekiq.server?
      end

      def worker_supported_words(candidates, at, atar)
        return Set.new if candidates.empty?
        return unless shared_exists?(at, atar)

        present = candidates.select { |word| shared_member?(at, atar, word) }
        present.to_set
      end

      def publish_snapshot(at, atar, words)
        word_set = words.to_set
        @snapshot = Snapshot.new(key: cache_key(at, atar), words: word_set, loaded_at: Time.current)
        write_shared(at, atar, word_set)
        word_set
      end

      def write_shared(at, atar, words)
        return if words.blank?

        key = shared_cache_key(at, atar)
        staging = "#{key}:staging:#{SecureRandom.hex(8)}"
        Sidekiq.redis do |redis|
          redis.call('DEL', staging)
          words.each_slice(500) { |slice| redis.call('SADD', staging, *slice) }
          redis.call('EXPIRE', staging, SHARED_TTL.to_i)
          # Rename is atomic. Readers see the old complete set or the new one.
          redis.call('RENAME', staging, key)
        end
        @shared_written_at = Time.current
      end

      def shared_exists?(at, atar)
        Sidekiq.redis { |redis| redis.call('EXISTS', shared_cache_key(at, atar)).to_i.positive? }
      end

      def shared_member?(at, atar, word)
        Sidekiq.redis { |redis| redis.call('SISMEMBER', shared_cache_key(at, atar), word).to_i == 1 }
      end

      def shared_cache_key(at, atar)
        "#{SHARED_CACHE_PREFIX}/#{TradeTariffBackend.service}/#{at}/#{atar}"
      end

      def cache_key(at, atar)
        [at, atar]
      end

      def fresh?(snapshot)
        snapshot.loaded_at > TTL.ago
      end

      def schedule_shared_republish(at, atar, words)
        return if @shared_checked_at && @shared_checked_at > 5.minutes.ago

        @shared_checked_at = Time.current
        Thread.new(at, atar, words.to_a) do |refresh_at, refresh_atar, refresh_words|
          Rails.application.executor.wrap do
            write_shared(refresh_at, refresh_atar, refresh_words) unless shared_exists?(refresh_at, refresh_atar)
          end
        rescue StandardError => e
          Rails.logger.warn("Search expansion vocabulary republish failed: #{e.class} #{e.message}")
        end
      end

      def claim_refresh_lock?
        Rails.cache.write(refresh_lock_key, true, expires_in: 2.minutes, unless_exist: true)
      end

      def refresh_lock_key
        "#{SHARED_CACHE_PREFIX}/#{TradeTariffBackend.service}/refresh_lock"
      end

      def schedule_refresh(atar)
        return if worker_process? || @refreshing

        MUTEX.synchronize do
          return if @refreshing
          return unless claim_refresh_lock?

          @refreshing = true
          @refresh_thread = Thread.new(atar) do |refresh_atar|
            # Spread cold starts so web processes do not all read at once.
            sleep(refresh_delay)
            Rails.application.executor.wrap do
              started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              refresh_at = Date.current
              words = with_read_connection { build(refresh_at, refresh_atar) }
              publish_snapshot(refresh_at, refresh_atar, words)
              elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
              Rails.logger.info("Search expansion vocabulary refreshed in #{elapsed_ms}ms with #{words.size} words")
            end
          rescue StandardError => e
            Rails.logger.warn("Search expansion vocabulary refresh failed: #{e.class} #{e.message}")
          ensure
            @refreshing = false
          end
        end
      end

      def refresh_delay
        rand(0.0..REFRESH_JITTER_SECONDS)
      end

      def with_read_connection(&block)
        if Sequel::Model.db.servers.include?(:reader)
          Sequel::Model.db.with_server(:reader, &block)
        else
          yield
        end
      end

      def build(at, atar)
        words = Set.new
        db = Sequel::Model.db

        each_description(db, at, words)
        each_page(db[:search_references].where(usage: 'search').exclude(title: nil).order(:id), :id) do |row|
          add_words(words, row[:title])
        end
        each_page(db[:goods_nomenclature_labels].where(expired: false).order(:goods_nomenclature_sid), :goods_nomenclature_sid) do |row|
          add_label_words(words, row)
        end

        if atar
          each_page(current_atar_rulings(db, at), :id) do |row|
            add_atar_words(words, row)
          end
        end

        words
      end

      def current_atar_rulings(db, at)
        db[:tariff_knowledge_public_atar_rulings]
          .where(Sequel[:validity_start_date] <= at)
          .where(Sequel.lit('validity_end_date >= ? OR validity_end_date IS NULL', at))
          .order(:id)
      end

      def each_description(db, at, words)
        last_sid = 0
        last_period_sid = 0

        loop do
          rows = db.fetch(description_page_sql, at, at, last_sid, last_period_sid).all
          break if rows.empty?

          rows.each { |row| add_words(words, row[:description]) }
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

      def each_page(dataset, key, &block)
        last = nil

        loop do
          page = dataset
          page = page.where(Sequel[key] > last) if last
          rows = page.limit(PAGE_SIZE).all
          break if rows.empty?

          rows.each(&block)
          break if rows.size < PAGE_SIZE

          last = rows.last[key]
        end
      end

      def add_label_words(words, row)
        add_words(words, row[:description])
        Array(row[:synonyms]).each { |text| add_words(words, text) }
        Array(row[:colloquial_terms]).each { |text| add_words(words, text) }
        Array(row[:known_brands]).each { |text| add_words(words, text) }
      end

      def add_atar_words(words, row)
        Array(row[:keywords]).each { |text| add_words(words, text) }
        Array(row[:derived_facts]).each { |text| add_words(words, text) }
      end

      def add_words(words, text)
        extract_words(text).each { |word| words << word }
      end
    end
  end
end
