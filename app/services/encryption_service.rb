class EncryptionService
  def self.encrypt_string(string)
    new.crypt.encrypt_and_sign(string)
  end

  def self.decrypt_string(encrypted_string)
    new.crypt.decrypt_and_verify(encrypted_string)
  end

  def crypt
    secret = TradeTariffBackend.identity_encryption_secret
    key = ActiveSupport::KeyGenerator.new(secret).generate_key('identity_token_encryption_v1', 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
