# frozen_string_literal: true

module SearchExport
  class ExpansionTerms
    def self.call(expansion_input:, sent_query:, synonym_terms:)
      terms = []
      ai_term = added_ai_term(expansion_input, sent_query)
      terms << ai_term if ai_term.present?
      terms.concat(Array(synonym_terms))
      terms.filter_map { |term| term.to_s.strip.presence }.uniq
    end

    # Returns the text a model added to the expansion input: the appended
    # suffix of a prefixed query, or the whole string when the model wrote a
    # rewrite instead of appending. Shared with Search::ExpansionVocabularyFilter.
    def self.added_ai_term(expansion_input, sent_query)
      input = expansion_input.to_s
      sent = sent_query.to_s
      return if sent.blank? || sent.casecmp?(input)

      prefix = "#{input} "
      if sent.downcase.start_with?(prefix.downcase)
        sent[prefix.length..].to_s.strip.presence
      else
        sent
      end
    end
  end
end
