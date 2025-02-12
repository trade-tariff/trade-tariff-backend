require 'rabl'
require 'v1_api'

Rabl::Engine.class_eval do
  include V1Api.routes.url_helpers
end

Rabl.configure do |config|
  config.include_json_root = false
  config.include_child_root = false
  config.cache_sources = false
  config.perform_caching = false
end
