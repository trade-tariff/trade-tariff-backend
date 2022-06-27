require 'uri'

class SearchQueryParser
  API_URL = ENV['TARIFF_QUERY_SEARCH_PARSER_URL']

  def initialize
    @client = Faraday.new(API_URL) do |conn|
      conn.request :json

      conn.response :raise_error
      conn.response :json
    end
  end

  def get_tokens(search_query_term)
    @client.get('tokens', q: search_query_term)
           .body
  end
end
