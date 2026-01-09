class CognitoTokenVerifier
  ISSUER = "https://cognito-idp.#{TradeTariffBackend.aws_region}.amazonaws.com/#{TradeTariffBackend.cognito_user_pool_id}".freeze
  JWKS_URL = "#{ISSUER}/.well-known/jwks.json".freeze

  Result = Struct.new(:valid, :payload, :reason, keyword_init: true) do
    def valid?
      valid
    end

    def expired?
      reason == :expired
    end
  end

  def self.verify_id_token(token)
    return Result.new(valid: false, payload: nil, reason: :missing_token) if token.blank?
    return Result.new(valid: false, payload: nil, reason: :missing_jwks_keys) if jwks_keys.nil? && !Rails.env.development?

    new(token).verify
  rescue JWT::ExpiredSignature
    Rails.logger.info('Cognito JWT::ExpiredSignature')
    Result.new(valid: false, payload: nil, reason: :expired)
  rescue JWT::DecodeError
    Rails.logger.info('Cognito JWT::DecodeError')
    Result.new(valid: false, payload: nil, reason: :invalid_token)
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
    if in_group?(verified)
      Result.new(valid: true, payload: verified, reason: nil)
    else
      Result.new(valid: false, payload: nil, reason: :not_in_group)
    end
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
