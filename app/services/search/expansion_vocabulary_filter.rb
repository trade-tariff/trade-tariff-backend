# frozen_string_literal: true

module Search
  # Keeps an added expansion term only when the tariff vocabulary supports it.
  #
  # Support is membership of an in-process word set. The search request does
  # not scan descriptions. A word inside another word, such as "car" inside
  # "carpet", is not a member of that set.
  class ExpansionVocabularyFilter
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
      return @original_query if supported.nil?

      surviving_phrases = phrases.select { |phrase| phrase_supported?(phrase, supported) }
      return @original_query if surviving_phrases.empty?

      [@original_query, surviving_phrases.uniq.join(', ')].join(' ')
    end

  private

    attr_reader :query_tokens

    def added_phrases(added_text)
      added_text.split(',').map { |phrase| ExpansionVocabulary.strip_surrounding_quotes(phrase.strip) }.compact_blank
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
      query_tokens.any? { |token| related_forms(token).include?(word) }
    end

    # A plural token is not pluralized again. "chickens" does not accept
    # "chickenss", and "buses" does not accept "buseses".
    def related_forms(token)
      singular = singular_form(token)
      return [singular, token].uniq if singular
      return [token] if competing_stems(token).size > 1

      [token, plural_form(token)].uniq
    end

    def plural_form(token)
      return "#{token.delete_suffix('y')}ies" if consonant_y?(token)
      return "#{token}es" if es_plural?(token)

      "#{token}s"
    end

    def singular_form(word)
      return if word.length < 4

      if word.end_with?('ies')
        stem = "#{word.delete_suffix('ies')}y"
        return stem if consonant_y?(stem) && plural_form(stem) == word
      end

      stems = competing_stems(word)
      stems.first if stems.size == 1
    end

    # "cases" is both cas + es and case + s. More than one stem means the
    # fold is ambiguous, so neither stem is granted without vocabulary support.
    def competing_stems(word)
      stems = []
      if word.end_with?('es')
        stem = word.delete_suffix('es')
        stems << stem if es_plural?(stem) && plural_form(stem) == word
      end
      if word.end_with?('s')
        stem = word.delete_suffix('s')
        stems << stem if !es_plural?(stem) && !consonant_y?(stem) && plural_form(stem) == word
      end
      stems.uniq
    end

    def es_plural?(stem)
      stem.match?(/[sxz]\z/) || stem.end_with?('ch', 'sh')
    end

    def consonant_y?(token)
      token.match?(/[^aeiou]y\z/)
    end

    def words(text)
      ExpansionVocabulary.extract_words(text)
    end

    def vocabulary_supported_words(candidate_words)
      return Set.new if candidate_words.empty?

      ExpansionVocabulary.supported_words(candidate_words)
    end
  end
end
