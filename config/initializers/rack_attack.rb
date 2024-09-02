if Rails.env.production?
  class Rack::Attack
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_URL'])

    API_KEY_LIMITS = JSON.parse(ENV['GREEN_LANES_API_KEYS'])

    if API_KEY_LIMITS.present?
      API_KEY_LIMITS['api_keys'].each do |api_key, config|
        throttle(api_key.to_s, limit: config['limit'], period: config['period'].to_i.hour) do |req|
          # Throttle by API key if the key matches
          req.env['HTTP_X_API_KEY'] == api_key
        end
      end
    end

    throttle('default', limit: 10, period: 1.hour) do |req|
      # Apply to all requests with an API key not in the list
      api_key = req.env['HTTP_X_API_KEY']
      API_KEY_LIMITS.blank? || (!API_KEY_LIMITS.key?(api_key) && api_key.present?)
    end
  end
else
  logger.info 'Rack::Attack is disabled in Dev env.'
end
