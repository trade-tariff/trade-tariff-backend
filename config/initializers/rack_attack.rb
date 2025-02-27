if Rails.env.production?
  class Rack::Attack
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV['REDIS_URL'])

    API_KEY_LIMITS = JSON.parse(ENV['GREEN_LANES_API_KEYS'])

    if API_KEY_LIMITS.present?
      API_KEY_LIMITS['api_keys'].each do |api_key, config|
        throttle(api_key.to_s, limit: config['limit'], period: config['period'].to_i.hour) do |req|
          req.path.start_with?('/green_lanes/goods_nomenclatures') && req.env['HTTP_X_API_KEY'] == api_key
        end
      end
    end
  end

  Rack::Attack.throttle('requests by ip', limit: 1_000, period: 60, &:ip)
else
  logger.info 'Rack::Attack is disabled in Dev env.'
end
