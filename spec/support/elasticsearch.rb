RSpec.configure do |config|
  config.before(:suite) do
    TradeTariffBackend.search_client.reindex_all
    TradeTariffBackend.cache_client.reindex_all
  end
end
