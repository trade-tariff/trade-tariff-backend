module EvaluationConfiguration
  # Describes every allowed evaluation override with enough metadata for a client to build its own
  # form fields without hardcoding a key's type or valid range — the admin app's launch form reads
  # this instead of duplicating AllowlistValidator's own knowledge of each key.
  class OverrideSchema
    RANGE_BY_KEY = {
      'candidate_limit' => AllowlistValidator::CANDIDATE_LIMIT_RANGE,
      'max_rounds' => AllowlistValidator::MAX_ROUNDS_RANGE,
      'rrf_k' => AllowlistValidator::RRF_K_RANGE,
      'vector_score_threshold' => AllowlistValidator::VECTOR_SCORE_THRESHOLD_RANGE,
      'vector_ef_search' => AllowlistValidator::VECTOR_EF_SEARCH_RANGE,
    }.freeze

    def self.call
      ALLOWED_OVERRIDE_KEYS.map { |key| entry_for(key) }
    end

    def self.entry_for(key)
      case key
      when *AllowlistValidator::MODEL_KEYS
        { name: key, config_type: 'options', options: OpenaiClient::MODEL_CONFIGS.keys.map { |model| { key: model, label: model } } }
      when *AllowlistValidator::BOOLEAN_KEYS
        { name: key, config_type: 'boolean' }
      else
        range = RANGE_BY_KEY.fetch(key)
        { name: key, config_type: 'integer', min: range.min, max: range.max }
      end
    end
    private_class_method :entry_for
  end
end
