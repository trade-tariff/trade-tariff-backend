RSpec.describe EncryptionService, type: :service do
  let(:string) { 'test_string' }
  let(:encrypted_string) { described_class.encrypt_string(string) }

  describe '.encrypt_string' do
    it 'returns a string' do
      expect(encrypted_string).to be_a(String)
    end

    it 'is different to the original string' do
      expect(encrypted_string).not_to eq(string)
    end
  end

  describe '.decrypt_string' do
    it 'decrypts an encrypted string back to the original' do
      decrypted_string = described_class.decrypt_string(encrypted_string)
      expect(decrypted_string).to eq(string)
    end

    it 'raises an error if the string cannot be decrypted' do
      expect {
        described_class.decrypt_string('invalid_encrypted_string')
      }.to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    end
  end
end
