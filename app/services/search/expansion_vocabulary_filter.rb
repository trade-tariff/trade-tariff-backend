# frozen_string_literal: true

module Search
  # Lexical evidence only: membership does not establish relevance to the query.
  # Phrases remain separate until accepted terms are rendered for retrieval.
  class ExpansionVocabularyFilter
    Result = Data.define(:expanded_query, :accepted_terms, :rejected_terms, :status)

    def self.call(original_query:, expanded_query: nil, added_terms: nil)
      new(original_query, expanded_query, added_terms).call
    end

    def initialize(original_query, expanded_query, added_terms)
      @query = original_query.to_s.strip
      @terms = if added_terms.nil?
                 # A legacy rewrite is one opaque proposal. Never infer phrase
                 # boundaries or answer refinements by splitting its contents.
                 Array(SearchExport::ExpansionTerms.added_ai_term(@query, expanded_query))
               else
                 Array(added_terms)
               end
      @terms = @terms.grep(String).map(&:strip).compact_blank.uniq(&:downcase)
    end

    def call
      return result([], [], :unchanged) if terms.empty?

      query_words = ExpansionVocabulary.extract_words(query).to_set
      words_by_term = terms.index_with { |term| ExpansionVocabulary.extract_words(term) }
      candidates = words_by_term.values.flatten.uniq.reject do |word|
        query_words.include?(word) || TradeTariffBackend.stop_words.include?(word)
      end
      lookup = ExpansionVocabulary.lookup(candidates)
      return result([], terms, :unavailable) unless lookup.ready?

      accepted, rejected = terms.partition do |term|
        words = words_by_term.fetch(term)
        words.any? && words.all? do |word|
          query_words.include?(word) || TradeTariffBackend.stop_words.include?(word) || lookup.words.include?(word)
        end
      end
      result(accepted, rejected, :ready)
    end

  private

    attr_reader :query, :terms

    def result(accepted, rejected, status)
      Result.new(
        expanded_query: [query, *accepted].compact_blank.join(' '),
        accepted_terms: accepted,
        rejected_terms: rejected,
        status:,
      )
    end
  end
end
