module IdentityApiClient
  def self.get_email(username)
    return nil unless username

    url = URI.join(TradeTariffBackend.identity_api_host, '/api/users/', username).to_s
    response = Faraday.get(url) do |req|
      req.headers['Authorization'] = "Token #{TradeTariffBackend.identity_api_key}"
      req.headers['Content-Type'] = 'application/json'
    end

    if response.success?
      JSON.parse(response.body)['user']['email']
    end
  end
end
