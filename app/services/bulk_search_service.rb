class BulkSearchService
  delegate :by_heading_search_client, to: TradeTariffBackend

  def initialize(id)
    @id = id
  end

  def call
    @result = BulkSearch::ResultCollection.find(id)

    return unless @result.queued?

    @result.processing!

    actions = @result.searches.flat_map do |search|
      [
        {},
        build_query_for(search),
      ]
    end

    response = by_heading_search_client.msearch(index: index_name, body: actions)

    @result.searches.each_with_index do |search, i|
      opensearch_results = response.dig('responses', i, 'hits', 'hits')
      search.search_results = (opensearch_results || []).map do |result|
        BulkSearch::SearchResult.build(
          number_of_digits: result['_source']['number_of_digits'],
          short_code: result['_source']['short_code'],
          score: result['_score'],
        )
      end

      search.no_results! if search.search_results.blank?
    end

    @result.complete!

    @result
  end

  private

  attr_reader :id

  def build_query_for(search)
    {
      query: {
        bool: {
          must: {
            query_string: {
              query: search.input_description,
              escape: true,
            },
          },
          filter: {
            term: {
              number_of_digits: search.number_of_digits,
            },
          },
        },
      },
      size:,
    }
  end

  def index_name
    Search::BulkSearchIndex.new.name
  end

  def size
    100
  end
end
