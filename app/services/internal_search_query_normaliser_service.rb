class InternalSearchQueryNormaliserService
  Result = Data.define(:query, :expanded_query)

  def self.call(query:, request_id: nil)
    new(query:, request_id:).call
  end

  def initialize(query:, request_id: nil)
    @query = query.to_s
    @request_id = request_id
  end

  def call
    Result.new(query: query, expanded_query: expanded_query)
  end

  private

  attr_reader :query, :request_id

  def expanded_query
    return query unless AdminConfiguration.enabled?('expand_search_enabled')

    result = Search::Instrumentation.query_expanded(
      request_id: request_id,
      original_query: query,
    ) { ExpandSearchQueryService.call(query) }

    result.expanded_query
  end
end
