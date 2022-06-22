class SearchQueryParser
  API_URL = ENV['TARIFF_QUERY_SEARCH_PARSER_URL']

  def initialize
    @client = Faraday.new(
      url: API_URL,
      headers: {'Content-Type' => 'application/json'}
      )
  end

  def get_tokens(search_query_term)
    api_response = @client.get("tokens/#{search_query_term}")

    response_data = api_response.success? ? JSON.parse(api_response.body) : {}

    {
      success: api_response.success?,
      status: api_response.status,
      data: response_data
    }
  end
end
