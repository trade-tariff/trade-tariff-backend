module ExchangeRates
  class XeApi
    class XeApiError < StandardError; end

    def initialize(date: Time.zone.today)
      @date = date.strftime('%Y-%m-%d')
    end

    def get_all_historic_rates
      send_request("/v1/historic_rate.json/?from=GBP&date=#{@date}&to=*&amount=1")
    end

    private

    def send_request(url)
      uri = URI(TradeTariffBackend.xe_api_url + url)

      client = Faraday.new(uri.host) do |conn|
        conn.request :basic_auth, TradeTariffBackend.xe_api_username, TradeTariffBackend.xe_api_password
      end

      response = client.get(uri)

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
