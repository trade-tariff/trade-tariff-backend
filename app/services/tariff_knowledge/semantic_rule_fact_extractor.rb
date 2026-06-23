module TariffKnowledge
  class SemanticRuleFactExtractor
    def self.call(fragment_node:, source_reference:, candidate_references:)
      new(fragment_node, source_reference, candidate_references).call
    end

    def initialize(fragment_node, source_reference, candidate_references)
      @fragment_node = fragment_node
      @source_reference = source_reference
      @candidate_references = candidate_references
    end

    def call
      facts = SemanticRuleFactValidator.call(
        facts: extracted_facts,
        source_text: fragment_node.content,
        valid_references:,
        target_references: candidate_references,
      )
      persist(facts)
      facts
    end

  private

    attr_reader :fragment_node, :source_reference, :candidate_references

    def valid_references
      [source_reference, *candidate_references].compact.uniq
    end

    def extracted_facts
      response = OpenaiClient.call(prompt)
      return [] unless response.is_a?(Hash)

      facts = response.fetch('facts', [])
      facts.is_a?(Array) ? facts : []
    end

    def persist(facts)
      metadata = fragment_node.metadata.to_h
      metadata['semantic_rule_facts'] = facts
      Node.where(id: fragment_node.id).update(metadata: Sequel.pg_jsonb(metadata))
      fragment_node.refresh
    end

    def prompt
      <<~PROMPT
        Evaluate deterministic candidate tariff connections for this source note fragment.

        Return JSON with a top-level "facts" array. Each fact must match this schema:
        {
          "source_reference": "source label",
          "source_span": "exact quoted text from the source fragment",
          "relationship_type": "excludes|includes|constrains|references|classifies",
          "subject": { "type": "section|chapter|heading|commodity|range|rule", "code": "01" },
          "target": { "type": "chapter|heading|commodity|range|rule", "code": "0101" },
          "conditions": ["condition text"],
          "exceptions": ["exception text"],
          "confidence": "high|medium|low"
        }

        Use only exact source_span text copied from the source fragment.
        Use only this deterministic source reference as the subject unless the source text explicitly names a candidate target:
        #{JSON.pretty_generate(source_reference)}

        Evaluate only these deterministic candidate target references:
        #{JSON.pretty_generate(candidate_references)}

        Use only subject and target references from this combined allow-list:
        #{JSON.pretty_generate(valid_references)}

        Source fragment:
        #{fragment_node.content}
      PROMPT
    end
  end
end
