module CognitoTokenVerifier
  ISSUER = "https://cognito-idp.#{ENV['AWS_REGION']}.amazonaws.com/#{ENV['COGNITO_USER_POOL_ID']}".freeze
  JWKS_URL = "#{ISSUER}/.well-known/jwks.json".freeze

  def self.verify_id_token(token)
    return nil if token.blank?
    return nil if jwks_keys.nil?

    decoded_token = JWT.decode(token, nil, true,
                               algorithms: %w[RS256],
                               jwks: { keys: jwks_keys },
                               iss: ISSUER,
                               verify_iss: true)

    decoded_token[0]
  rescue StandardError
    nil
  end

  def self.jwks_keys
    Rails.cache.fetch('cognito_jwks_keys', expires_in: 1.hour) do
      response = Faraday.get(JWKS_URL)
      JSON.parse(response.body)['keys'] if response.success?
    end
  end
end
