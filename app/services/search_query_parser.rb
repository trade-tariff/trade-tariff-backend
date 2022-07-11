class SearchQueryParser
  delegate :client, to: :class

  def initialize(search_query)
    @search_query = search_query
  end

  def call
    result_attributes = client.get('tokens', q: @search_query).body

    Beta::Search::SearchQueryParserResult.build(result_attributes)
  end

  def self.client
    @client ||= Faraday.new(TradeTariffBackend.search_query_parser_url) do |conn|
      conn.response :raise_error
      conn.response :json
    end
  end
end
