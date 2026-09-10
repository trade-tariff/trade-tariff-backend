module IdentityApiClient
  def self.get_email(username)
    return nil unless username

    response = user_request(:get, username)
    if response.success?
      JSON.parse(response.body)['user']['email']
    end
  end

  class DeletionError < StandardError; end

  def self.delete_user(username)
    return nil unless username

    response = user_request(:delete, username)

    return true if response.success?

    # No status is treated as an acceptable failure here. The identity service
    # answers a delete for an unknown user with 200, so anything else means the
    # deletion did not happen and external_id must stay put.
    raise DeletionError, "Identity deletion for #{username} returned HTTP #{response.status}"
  end

  def self.user_request(method, username)
    url = URI.join(TradeTariffBackend.identity_api_host, '/api/users/', username).to_s
    Faraday.public_send(method, url) do |req|
      req.headers['Authorization'] = "Token #{TradeTariffBackend.identity_api_key}"
      req.headers['Content-Type'] = 'application/json'
    end
  end
end
