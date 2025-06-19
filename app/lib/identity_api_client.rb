module IdentityApiClient
  def self.get_email(username)
    return nil unless username

    response = user_request(:get, username)
    if response.success?
      JSON.parse(response.body)['user']['email']
    end
  end

  def self.delete_user(username)
    return nil unless username

    response = user_request(:delete, username)
    response.success?
  end

  def self.user_request(method, username)
    url = URI.join(TradeTariffBackend.identity_api_host, '/api/users/', username).to_s
    Faraday.public_send(method, url) do |req|
      req.headers['Authorization'] = "Token #{TradeTariffBackend.identity_api_key}"
      req.headers['Content-Type'] = 'application/json'
    end
  end
end
