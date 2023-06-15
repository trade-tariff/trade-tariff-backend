class BulkSearchService
  delegate :v2_search_client, to: TradeTariffBackend

  def initialize(id)
    @id = id
  end

  def call
    @result = BulkSearch::ResultCollection.find(id)

    return unless @result.status.queued?

    @result.processing!

    actions = @result.searches.each_with_object([]) do |search, acc|
      acc << {}
      acc << build_query_for(search)
    end

    response = v2_search_client.msearch(index: index_name, body: actions)
    @result.searches.each_with_index do |search, i|
      opensearch_results = response.dig('responses', i, 'hits', 'hits')
      AncestorSearchResultService.new(search, opensearch_results).call
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
        },
      },
      size:,
    }
  end

  def index_name
    Search::GoodsNomenclatureIndex.new.name
  end

  def size
    200
  end
end
