require 'rabl'

Rabl.configure do |config|
  config.include_json_root = false
  config.include_child_root = false
  config.cache_sources = false
  config.perform_caching = false
end
