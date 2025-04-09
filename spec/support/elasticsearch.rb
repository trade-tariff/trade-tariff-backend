RSpec.configure do |config|
  config.before(:suite) do
    connection_attempts ||= 0

    TradeTariffBackend.search_client.reindex_all
  rescue Faraday::ConnectionFailed => e
    connection_attempts += 1

    if connection_attempts < 15
      warn "[#{connection_attempts}/15] Waiting for ElasticSearch, retrying in 2 seconds"
      sleep 2
      retry
    else
      warn "Could not connect to ElasticSearch on #{TradeTariffBackend.opensearch_configuration[:host]}, giving up"
      raise e
    end
  end
end
