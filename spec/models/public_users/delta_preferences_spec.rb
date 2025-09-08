RSpec.describe PublicUsers::DeltaPreferences do
  let!(:user) { create(:public_user) }

  describe 'associations' do
    it 'has a user association' do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)
    end
  end

  describe 'validations' do
    before do
      user
    end

    it 'validates commodity_codes format with valid input' do
      preference = described_class.new(user_id: user.id, commodity_code: '1234567891')
      expect(preference.valid?).to be true
    end

    it 'validates commodity_codes format with empty input' do
      preference = described_class.new(user_id: user.id, commodity_code: '')
      expect(preference.valid?).to be false
    end

    it 'allows the same user to have multiple different commodity_codes' do
      described_class.create(user_id: user.id, commodity_code: '1234567890')
      second = described_class.new(user_id: user.id, commodity_code: '1234567891')

      expect(second.valid?).to be true
      expect { second.save }.not_to raise_error
    end

    it 'rejects duplicate commodity_code for the same user' do
      described_class.create(user_id: user.id, commodity_code: '1234567890')
      dup = described_class.new(user_id: user.id, commodity_code: '1234567890')
      expect(dup.valid?).to be false
      expect { dup.save(validate: false) }.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end
end
