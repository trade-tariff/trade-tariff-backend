module EvaluationConfiguration
  class BaselineProvider
    def self.call
      # Baseline includes 9 of 11 ALLOWED_OVERRIDE_KEYS. simulator_model is omitted
      # because production uses real humans (no backend model config; orchestration choice).
      # filter_prefixes is omitted because it's already a plain request param (override-only).
      {
        'rrf_k' => AdminConfiguration.integer_value('rrf_k'),
        'vector_score_threshold' => AdminConfiguration.integer_value('vector_score_threshold'),
        'vector_ef_search' => AdminConfiguration.integer_value('vector_ef_search'),
        'search_non_declarables' => AdminConfiguration.enabled?('search_non_declarables'),
        'search_compressed_notes_enabled' => AdminConfiguration.enabled?('search_compressed_notes_enabled'),
        'search_general_rules_enabled' => AdminConfiguration.enabled?('search_general_rules_enabled'),
        'candidate_limit' => AdminConfiguration.integer_value('opensearch_result_limit'),
        'max_rounds' => AdminConfiguration.integer_value('interactive_search_max_questions'),
        'question_model' => AdminConfiguration.nested_options_value('search_model')[:selected],
      }
    end
  end
end
