module Search
  module FailureCodes
    QUERY_EXPANSION_FAILED = 'query_expansion_failed'.freeze
    EMBEDDING_GENERATION_FAILED = 'embedding_generation_failed'.freeze
    VECTOR_RETRIEVAL_FAILED = 'vector_retrieval_failed'.freeze
    INTERACTIVE_SEARCH_FAILED = 'interactive_search_failed'.freeze
    DUPLICATE_QUESTION_VALIDATION_FAILED = 'duplicate_question_validation_failed'.freeze
    OPENSEARCH_FAILED = 'opensearch_failed'.freeze

    ALL = [
      QUERY_EXPANSION_FAILED,
      EMBEDDING_GENERATION_FAILED,
      VECTOR_RETRIEVAL_FAILED,
      INTERACTIVE_SEARCH_FAILED,
      DUPLICATE_QUESTION_VALIDATION_FAILED,
      OPENSEARCH_FAILED,
    ].freeze

    LOG_FIELDS = [:search_degraded, *ALL.map(&:to_sym)].freeze
    OPERATIONS = {
      'search_query_expansion' => QUERY_EXPANSION_FAILED,
      'vector_search_query_embedding' => EMBEDDING_GENERATION_FAILED,
      'interactive_search' => INTERACTIVE_SEARCH_FAILED,
      'interactive_search_final_answer' => INTERACTIVE_SEARCH_FAILED,
      'duplicate_question_retry' => INTERACTIVE_SEARCH_FAILED,
      'duplicate_question_validator' => DUPLICATE_QUESTION_VALIDATION_FAILED,
    }.freeze

    def self.logging_fields(failure_codes)
      failures = Array(failure_codes)
      { search_degraded: failures.any? }.merge(ALL.index_with { |code| failures.include?(code) }.transform_keys(&:to_sym))
    end

    def self.for_operation(operation)
      OPERATIONS[operation]
    end
  end
end
