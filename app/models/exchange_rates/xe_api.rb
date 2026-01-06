module ExchangeRates
  class XeApi
    delegate :client, to: :class

    class XeApiError < StandardError; end

    PATH = '/v1/historic_rate.json/?from=GBP&date=%{date}&to=*&amount=1'.freeze

    def initialize(date: Time.zone.today)
      @date = date.strftime('%Y-%m-%d')
    end

    def get_all_historic_rates
      path = sprintf(PATH, date: @date)
      send_request(path)
    end

    def self.client
      @client ||= Faraday.new(TradeTariffBackend.xe_api_url) do |conn|
        conn.set_basic_auth(
          TradeTariffBackend.xe_api_username,
          TradeTariffBackend.xe_api_password,
        )
      end
    end

    private

    def send_request(path)
      response = client.get(path)

      if response.success?
        JSON.parse(response.body)
      else
        raise XeApiError, "Server error: Unsuccessful response code #{response.status}"
      end
    rescue Faraday::Error => e
      raise XeApiError, "Server error: #{e.message}"
    end
  end
end
