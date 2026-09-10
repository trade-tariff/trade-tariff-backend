module IdentityApiClient
  class LookupError < StandardError; end

  def self.get_email(username)
    return nil unless username

    response = user_request(:get, username)

    return JSON.parse(response.body)['user']['email'] if response.success?
    return nil if response.status == 404

    raise LookupError, "Identity lookup for #{username} returned HTTP #{response.status}"
  end

  def self.delete_user(username)
    return nil unless username

    response = user_request(:delete, username)
    response.success?
  end

  def self.user_request(method, username)
    url = URI.join(TradeTariffBackend.identity_api_host, '/api/users/', username).to_s

    connection.public_send(method, url) do |req|
      req.headers['Authorization'] = "Token #{TradeTariffBackend.identity_api_key}"
      req.headers['Content-Type'] = 'application/json'
    end
  end

  def self.connection
    pem = TradeTariffBackend.internal_ca_pem

    if @connection.nil? || @connection_pem != pem
      @connection_pem = pem
      @connection = Faraday.new(ssl: ssl_options)
    end

    @connection
  end

  def self.ssl_options
    pem = TradeTariffBackend.internal_ca_pem
    return {} if pem.blank?

    store = OpenSSL::X509::Store.new
    store.set_default_paths
    store.add_cert(OpenSSL::X509::Certificate.new(pem))

    { cert_store: store }
  end
end
