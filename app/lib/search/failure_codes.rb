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
  end
end
