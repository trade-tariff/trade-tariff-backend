class CognitoTokenVerifier
  ISSUER = "https://cognito-idp.#{TradeTariffBackend.aws_region}.amazonaws.com/#{TradeTariffBackend.cognito_user_pool_id}".freeze
  JWKS_URL = "#{ISSUER}/.well-known/jwks.json".freeze

  def self.verify_id_token(token)
    return nil if token.blank?
    return nil if jwks_keys.nil? && !Rails.env.development?

    new(token).verify
  rescue JWT::ExpiredSignature
    Rails.logger.info('Cognito JWT::ExpiredSignature')
    nil
  rescue JWT::DecodeError
    Rails.logger.info('Cognito JWT::DecodeError')
    nil
  end

  def self.jwks_keys
    Rails.cache.fetch('cognito_jwks_keys', expires_in: 1.hour) do
      response = Faraday.get(JWKS_URL)
      JSON.parse(response.body)['keys'] if response.success?
    end
  end

  attr_accessor :token

  def initialize(token)
    @token = token
  end

  def verify
    verified = decrypt.decode.token[0]
    in_group?(verified) ? verified : nil
  end

  def decrypt
    unless Rails.env.development?
      self.token = EncryptionService.decrypt_string(token)
    end
    self
  end

  def decode
    self.token = if Rails.env.development?
                   JWT.decode(token, nil, false)
                 else
                   JWT.decode(token, nil, true,
                              algorithms: %w[RS256],
                              jwks: { keys: CognitoTokenVerifier.jwks_keys },
                              iss: ISSUER,
                              verify_iss: true)
                 end
    self
  end

  def in_group?(token)
    groups = token['cognito:groups'] || []
    groups.include?('myott')
  end
end
