module EvaluationConfiguration
  ALLOWED_OVERRIDE_KEYS = %w[
    question_model
    simulator_model
    candidate_limit
    max_rounds
    rrf_k
    vector_score_threshold
    vector_ef_search
    search_non_declarables
    search_compressed_notes_enabled
    search_general_rules_enabled
  ].freeze

  class AllowlistValidator
    MODEL_KEYS = %w[question_model simulator_model].freeze
    BOOLEAN_KEYS = %w[
      search_non_declarables
      search_compressed_notes_enabled
      search_general_rules_enabled
    ].freeze

    # Upper bounds below are set a few multiples above the corresponding
    # AdminConfiguration::DEFAULTS value, so an evaluation caller can stress-test
    # configuration without being able to force a pathologically expensive call.
    # candidate_limit overrides opensearch_result_limit (default 50, app/models/admin_configuration.rb)
    # and is used as the retrieval `limit:` in Api::Internal::SearchService#opensearch_result_limit.
    CANDIDATE_LIMIT_RANGE = (1..250)
    # max_rounds overrides interactive_search_max_questions (default 7); each round is a
    # clarifying-question LLM call in InteractiveSearchService, so the ceiling stays small.
    MAX_ROUNDS_RANGE = (1..20)
    # rrf_k is used as `1.0 / (rank + k)` in HybridRetrievalService#rrf_merge (default 60).
    # Negative values can zero/flip the denominator for low ranks; large values just flatten
    # rank differences, so 0 is the floor and the ceiling only needs to stay numerically sane.
    RRF_K_RANGE = (0..1000)
    # vector_score_threshold is a cosine-similarity percentage (.../100.0) in
    # VectorRetrievalService#apply_score_threshold, so it is bounded to a real percentage.
    VECTOR_SCORE_THRESHOLD_RANGE = (0..100)
    # vector_ef_search is a Postgres HNSW `SET LOCAL hnsw.ef_search` tuning knob (default 100,
    # app/services/vector_retrieval_service.rb); excessive values increase query cost significantly.
    VECTOR_EF_SEARCH_RANGE = (1..1000)

    def self.call(overrides)
      normalized = overrides.to_h { |key, value| [key.to_s, value] }

      disallowed = normalized.keys - ALLOWED_OVERRIDE_KEYS
      raise OverrideValidationError, "Disallowed override keys: #{disallowed.join(', ')}" if disallowed.any?

      normalized.each { |key, value| validate_value(key, value) }

      true
    end

    def self.validate_value(key, value)
      case key
      when *MODEL_KEYS then validate_model(key, value)
      when 'candidate_limit' then validate_integer(key, value, CANDIDATE_LIMIT_RANGE)
      when 'max_rounds' then validate_integer(key, value, MAX_ROUNDS_RANGE)
      when 'rrf_k' then validate_integer(key, value, RRF_K_RANGE)
      when 'vector_score_threshold' then validate_integer(key, value, VECTOR_SCORE_THRESHOLD_RANGE)
      when 'vector_ef_search' then validate_integer(key, value, VECTOR_EF_SEARCH_RANGE)
      when *BOOLEAN_KEYS then validate_boolean(key, value)
      end
    end
    private_class_method :validate_value

    def self.validate_model(key, value)
      return if value.is_a?(String) && OpenaiClient::MODEL_CONFIGS.key?(value)

      raise OverrideValidationError, "#{key} must be one of: #{OpenaiClient::MODEL_CONFIGS.keys.join(', ')}"
    end
    private_class_method :validate_model

    def self.validate_integer(key, value, range)
      raise OverrideValidationError, "#{key} must be an Integer" unless value.is_a?(Integer)
      raise OverrideValidationError, "#{key} must be between #{range.min} and #{range.max}" unless range.cover?(value)
    end
    private_class_method :validate_integer

    def self.validate_boolean(key, value)
      return if value.is_a?(TrueClass) || value.is_a?(FalseClass)

      raise OverrideValidationError, "#{key} must be true or false"
    end
    private_class_method :validate_boolean
  end
end
