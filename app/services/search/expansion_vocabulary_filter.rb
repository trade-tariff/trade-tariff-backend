# frozen_string_literal: true

module Search
  # Keeps an added expansion term only when the tariff vocabulary supports it.
  #
  # The vocabulary is the current nomenclature descriptions, the public search
  # references, the non-expired goods nomenclature label text, and, when ATaR
  # search is enabled, the public ATaR ruling search terms. One SQL statement
  # checks the whole candidate set with word-bounded regular expressions, so
  # "car" is never supported because it occurs inside "carpet".
  class ExpansionVocabularyFilter
    WORD_PATTERN = /[\p{alnum}']+/
    private_constant :WORD_PATTERN

    # A quote that sits between a word boundary and a word character surrounds
    # a term. A quote between two word characters, such as the apostrophe in
    # "o'clock" or "poultry's", is kept.
    OPENING_QUOTE_PATTERN = /(?<![\p{alnum}'"])["'](?=\p{alnum})/
    private_constant :OPENING_QUOTE_PATTERN

    CLOSING_QUOTE_PATTERN = /(?<=\p{alnum})["'](?![\p{alnum}'"])/
    private_constant :CLOSING_QUOTE_PATTERN

    def self.call(original_query:, expanded_query:)
      new(original_query, expanded_query).call
    rescue StandardError => e
      # Fail closed: a lookup failure must not let a substituted rewrite through.
      # The original query keeps the search itself successful.
      Rails.logger.warn("Search expansion vocabulary filter failed: #{e.class} #{e.message}")
      original_query.to_s
    end

    def initialize(original_query, expanded_query)
      @original_query = original_query.to_s.squish
      @expanded_query = expanded_query.to_s.squish
      @query_tokens = words(@original_query)
    end

    def call
      return @expanded_query if @expanded_query.blank?
      return @original_query if @expanded_query.casecmp?(@original_query)

      added_text = SearchExport::ExpansionTerms.added_ai_term(@original_query, @expanded_query)
      return @original_query if added_text.blank?

      phrases = added_phrases(added_text)
      return @original_query if phrases.empty?

      supported = vocabulary_supported_words(candidate_words(phrases))

      surviving_phrases = phrases.select { |phrase| phrase_supported?(phrase, supported) }
      return @original_query if surviving_phrases.empty?

      [@original_query, surviving_phrases.uniq.join(', ')].join(' ')
    end

  private

    attr_reader :query_tokens

    def added_phrases(added_text)
      added_text.split(',').map { |phrase| strip_surrounding_quotes(phrase.strip) }.compact_blank
    end

    def candidate_words(phrases)
      phrases
        .flat_map { |phrase| words(phrase) }
        .uniq
        .reject { |word| stop_word?(word) || morphological_variant?(word) }
    end

    def phrase_supported?(phrase, supported)
      phrase_words = words(phrase)
      phrase_words.present? && phrase_words.all? { |word| word_supported?(word, supported) }
    end

    def word_supported?(word, supported)
      stop_word?(word) || morphological_variant?(word) || supported.include?(word)
    end

    def stop_word?(word)
      TradeTariffBackend.stop_words.include?(word)
    end

    # A variant is only a simple plural or singular fold when the folded
    # suffix was actually present. delete_suffix returns the receiver when the
    # suffix is absent, so "chicken" would otherwise fold to "chickenies" and
    # "chickeny".
    def morphological_variant?(word)
      query_tokens.any? do |token|
        word == token ||
          ["#{token}s", "#{token}es"].include?(word) ||
          (token.end_with?('y') && word == "#{token.delete_suffix('y')}ies") ||
          (word.end_with?('s') && word.delete_suffix('s') == token) ||
          (word.end_with?('es') && word.delete_suffix('es') == token) ||
          (word.end_with?('ies') && "#{word.delete_suffix('ies')}y" == token) ||
          (token.end_with?('s') && token.delete_suffix('s') == word) ||
          (token.end_with?('es') && token.delete_suffix('es') == word) ||
          (token.end_with?('ies') && "#{token.delete_suffix('ies')}y" == word)
      end
    end

    def words(text)
      text.to_s.downcase.scan(WORD_PATTERN)
          .map { |word| strip_surrounding_quotes(word) }
          .select { |word| word.match?(/\p{alnum}/) }
    end

    def strip_surrounding_quotes(text)
      text.gsub(OPENING_QUOTE_PATTERN, '').gsub(CLOSING_QUOTE_PATTERN, '')
    end

    def vocabulary_supported_words(candidate_words)
      return Set.new if candidate_words.empty?

      Sequel::Model.db.fetch(vocabulary_sql, *vocabulary_bind_arguments(candidate_words)).map(:word).to_set
    end

    def vocabulary_bind_arguments(candidate_words)
      point_in_time = TradeTariffRequest.time_machine_now
      arguments = [candidate_words.join(',')]
      arguments.concat([point_in_time, point_in_time]) if point_in_time.present?
      arguments
    end

    def vocabulary_sql
      atar_clause = if AdminConfiguration.enabled?('search_atars_enabled')
                      <<~ATAR
                        OR EXISTS (
                          SELECT 1
                          FROM tariff_knowledge_public_atar_rulings a
                          WHERE (array_to_string(a.keywords, ' ') || ' ' || array_to_string(a.derived_facts, ' ')) ~* ('\\y' || candidates.word || '\\y')
                        )
                      ATAR
                    end

      <<~SQL
        SELECT DISTINCT candidates.word
        FROM unnest(string_to_array(?, ',')) AS candidates(word)
        WHERE EXISTS (
          SELECT 1
          FROM goods_nomenclature_descriptions d
          JOIN goods_nomenclature_description_periods p
            ON p.goods_nomenclature_description_period_sid = d.goods_nomenclature_description_period_sid
           AND p.goods_nomenclature_sid = d.goods_nomenclature_sid
          WHERE d.description IS NOT NULL
            AND #{descriptions_validity_sql}
            AND d.description ~* ('\\y' || candidates.word || '\\y')
        ) OR EXISTS (
          SELECT 1
          FROM search_references r
          WHERE r.usage = 'search'
            AND r.title IS NOT NULL
            AND r.title ~* ('\\y' || candidates.word || '\\y')
        ) OR EXISTS (
          SELECT 1
          FROM goods_nomenclature_labels l
          WHERE l.expired = FALSE
            AND (
              l.description ~* ('\\y' || candidates.word || '\\y')
              OR array_to_string(l.synonyms, ' ') ~* ('\\y' || candidates.word || '\\y')
              OR array_to_string(l.colloquial_terms, ' ') ~* ('\\y' || candidates.word || '\\y')
              OR array_to_string(l.known_brands, ' ') ~* ('\\y' || candidates.word || '\\y')
            )
        ) #{atar_clause}
      SQL
    end

    def descriptions_validity_sql
      return 'TRUE' if TradeTariffRequest.time_machine_now.blank?

      'p.validity_start_date <= ? AND (p.validity_end_date >= ? OR p.validity_end_date IS NULL)'
    end
  end
end
