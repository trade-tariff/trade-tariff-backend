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

    # Plain-language, for an operator who isn't a developer and has never read the search
    # pipeline's own code — written for the launch form's "Overrides" section, not as internal
    # documentation (see each key's own usage for the technical version: InteractiveSearchService,
    # VectorRetrievalService, OpensearchRetrievalService, HybridRetrievalService#rrf_merge).
    DESCRIPTION_BY_KEY = {
      'question_model' => 'The AI model used to generate clarifying questions during the search.',
      'simulator_model' => 'The AI model that plays the role of the person answering clarifying questions, standing in for a real user during an evaluation run.',
      'candidate_limit' => "How many results OpenSearch returns before they're re-ranked and narrowed down.",
      'max_rounds' => 'The most clarifying questions the search can ask before it has to give its best answer.',
      'rrf_k' => 'A tuning number for how results from different search methods get combined into one ranking — smaller numbers favour whichever method already ranked a result near the top.',
      'vector_score_threshold' => 'The minimum similarity score (as a percentage) a result needs to count as a real match in the vector search.',
      'vector_ef_search' => 'How thoroughly the vector search index is searched — higher numbers check more candidates (more accurate, slower); lower numbers are faster but may miss some matches.',
      'search_non_declarables' => "Include commodity codes that can't actually be declared on their own (e.g. chapter or heading-level codes) in the results.",
      'search_compressed_notes_enabled' => 'Include AI-summarised classification notes for each candidate code as extra context for the clarifying questions.',
      'search_general_rules_enabled' => 'Include the General Rules of Interpretation (the legal rules customs classification is based on) as extra context for the clarifying questions.',
    }.freeze

    def self.call
      ALLOWED_OVERRIDE_KEYS.map { |key| entry_for(key) }
    end

    def self.entry_for(key)
      description = DESCRIPTION_BY_KEY.fetch(key)

      case key
      when *AllowlistValidator::MODEL_KEYS
        { name: key, config_type: 'options', options: OpenaiClient::MODEL_CONFIGS.keys.map { |model| { key: model, label: model } }, description: }
      when *AllowlistValidator::BOOLEAN_KEYS
        { name: key, config_type: 'boolean', description: }
      else
        range = RANGE_BY_KEY.fetch(key)
        { name: key, config_type: 'integer', min: range.min, max: range.max, description: }
      end
    end
    private_class_method :entry_for
  end
end
