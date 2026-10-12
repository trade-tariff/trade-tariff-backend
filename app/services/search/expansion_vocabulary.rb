# frozen_string_literal: true

module Search
  # In-process word set for expansion filtering.
  #
  # A search request only checks this set. It does not scan descriptions.
  # The set is built on a background thread after the first search in the
  # process, then refreshed in the background when it is stale. A cold
  # process has no set yet, so the filter keeps the original query.
  #
  # Do not load this set from an initializer or a worker. Workers must not
  # build or retain it.
  class ExpansionVocabulary
    TTL = 1.hour
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
        key = cache_key(at, atar)
        snapshot = @snapshot

        if snapshot&.key == key
          schedule_refresh(at, atar) if !fresh?(snapshot) && !Rails.env.test?
          return select_supported(snapshot.words, candidates)
        end

        return select_supported(build(at, atar), candidates) if Rails.env.test?

        schedule_refresh(at, atar)
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

      def cache_key(at, atar)
        [at, atar]
      end

      def fresh?(snapshot)
        snapshot.loaded_at > TTL.ago
      end

      def schedule_refresh(at, atar)
        return if @refreshing

        MUTEX.synchronize do
          return if @refreshing

          @refreshing = true
          Thread.new(at, atar) do |refresh_at, refresh_atar|
            Rails.application.executor.wrap do
              started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              words = Sequel::Model.db.synchronize { build(refresh_at, refresh_atar) }
              @snapshot = Snapshot.new(
                key: cache_key(refresh_at, refresh_atar),
                words:,
                loaded_at: Time.current,
              )
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

      def build(at, atar)
        words = Set.new
        db = Sequel::Model.db

        description_texts(db, at).each { |text| add_words(words, text) }
        db[:search_references].where(usage: 'search').exclude(title: nil).select_map(:title).each { |text| add_words(words, text) }
        db[:goods_nomenclature_labels].where(expired: false).select(:description, :synonyms, :colloquial_terms, :known_brands).each do |row|
          add_words(words, row[:description])
          Array(row[:synonyms]).each { |text| add_words(words, text) }
          Array(row[:colloquial_terms]).each { |text| add_words(words, text) }
          Array(row[:known_brands]).each { |text| add_words(words, text) }
        end

        if atar
          db[:tariff_knowledge_public_atar_rulings].select(:keywords, :derived_facts).each do |row|
            Array(row[:keywords]).each { |text| add_words(words, text) }
            Array(row[:derived_facts]).each { |text| add_words(words, text) }
          end
        end

        words
      end

      def description_texts(db, at)
        db.fetch(<<~SQL, at, at).select_map(:description)
          SELECT d.description
          FROM goods_nomenclature_descriptions d
          JOIN goods_nomenclature_description_periods p
            ON p.goods_nomenclature_description_period_sid = d.goods_nomenclature_description_period_sid
           AND p.goods_nomenclature_sid = d.goods_nomenclature_sid
          WHERE d.description IS NOT NULL
            AND p.validity_start_date <= ?
            AND (p.validity_end_date >= ? OR p.validity_end_date IS NULL)
        SQL
      end

      def add_words(words, text)
        extract_words(text).each { |word| words << word }
      end
    end
  end
end
