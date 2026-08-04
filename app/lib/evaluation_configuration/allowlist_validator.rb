module EvaluationConfiguration
  class OverrideValidationError < StandardError; end

  ALLOWED_OVERRIDE_KEYS = %w[
    question_model
    simulator_model
    candidate_limit
    max_rounds
    rrf_k
    vector_score_threshold
    vector_ef_search
    search_non_declarables
    filter_prefixes
    search_compressed_notes_enabled
    search_general_rules_enabled
  ].freeze

  class AllowlistValidator
    def self.call(overrides)
      disallowed = overrides.keys.map(&:to_s) - ALLOWED_OVERRIDE_KEYS
      raise OverrideValidationError, "Disallowed override keys: #{disallowed.join(', ')}" if disallowed.any?

      true
    end
  end
end
