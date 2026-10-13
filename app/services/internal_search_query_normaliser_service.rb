class InternalSearchQueryNormaliserService
  Result = Data.define(:query, :expanded_query, :added_terms) do
    def initialize(query:, expanded_query:, added_terms: nil)
      super
    end
  end

  def self.call(query:, request_id: nil)
    new(query:, request_id:).call
  end

  def initialize(query:, request_id: nil)
    @query = query.to_s
    @request_id = request_id
  end

  def call
    unless AdminConfiguration.enabled?('expand_search_enabled')
      return Result.new(query:, expanded_query: query, added_terms: [])
    end

    proposal = Search::Instrumentation.query_expanded(
      request_id:,
      original_query: query,
    ) { ExpandSearchQueryService.call(query, request_id:) }

    filtered = Search::ExpansionVocabularyFilter.call(
      original_query: query,
      expanded_query: proposal.expanded_query,
      added_terms: proposal.added_terms,
    )
    Result.new(query:, expanded_query: filtered.expanded_query, added_terms: filtered.accepted_terms)
  end

private

  attr_reader :query, :request_id
end
