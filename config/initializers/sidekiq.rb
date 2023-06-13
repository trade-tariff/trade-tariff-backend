require 'sidekiq'
require 'query_count_job_logger'

redis_config = PaasConfig.redis

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.redis = redis_config
  config[:job_logger] = ::QueryCountJobLogger
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
