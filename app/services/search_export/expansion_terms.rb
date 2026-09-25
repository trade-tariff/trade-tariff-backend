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

    def self.added_ai_term(expansion_input, sent_query)
      input = expansion_input.to_s
      sent = sent_query.to_s
      return if sent.blank? || sent == input

      if sent.start_with?("#{input} ")
        sent.delete_prefix("#{input} ").strip.presence
      else
        sent
      end
    end

    private_class_method :added_ai_term
  end
end
