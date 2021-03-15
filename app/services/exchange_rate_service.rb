class ExchangeRateService
  API_URL = 'https://api.exchangeratesapi.io/latest'.freeze
  EXCHANGE_RATES_UTC_REFRESH_HOUR = 15
  EXCHANGE_RATES_UTC_REFRESH_MIN  = 15
  REDIS_KEY = 'trade-tariff-exchange-rates'.freeze

  def call
    cached_exchange_rates || fetched_exchange_rates
  end

  private

  def cached_exchange_rates(ignore_expiry: false)
    response = TradeTariffBackend.redis.get(REDIS_KEY)

    if response.present?
      exchange_rates = JSON.parse(response)
      exchange_rates['expires_at'] = Time.zone.parse(exchange_rates['expires_at'])

      return exchange_rates if ignore_expiry
      return exchange_rates if exchange_rates['expires_at'] > now
    end

    nil
  end

  def fetched_exchange_rates
    response = Faraday.new(API_URL).get

    if response.success?
      exchange_rates = JSON.parse(response.body)
      exchange_rates['expires_at'] = expires_at.iso8601

      TradeTariffBackend.redis.set(REDIS_KEY, exchange_rates.to_json)

      exchange_rates['expires_at'] = Time.zone.parse(exchange_rates['expires_at'])
      exchange_rates
    else
      cached_exchange_rates(ignore_expiry: true)
    end
  end

  def expires_at
    relative_day.change(
      hour: EXCHANGE_RATES_UTC_REFRESH_HOUR,
      min: EXCHANGE_RATES_UTC_REFRESH_MIN,
    )
  end

  def relative_day
    return now.tomorrow if now.hour > EXCHANGE_RATES_UTC_REFRESH_HOUR

    now
  end

  def now
    Time.zone.now
  end
end
