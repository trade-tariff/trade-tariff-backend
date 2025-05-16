RSpec.describe PublicUsers::Preferences do
  describe 'associations' do
    it 'has a user association' do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)
    end
  end

  describe 'validations' do
    it 'validates chapter_ids format with valid input' do
      preference = described_class.new(user_id: 1, chapter_ids: '01,02,03')
      expect(preference.valid?).to be true
    end

    it 'validates chapter_ids format with invalid input' do
      preference = described_class.new(user_id: 1, chapter_ids: 'invalid_format')
      expect(preference.valid?).to be false
    end

    it 'validates chapter_ids format with empty input' do
      preference = described_class.new(user_id: 1, chapter_ids: '')
      expect(preference.valid?).to be true
    end
  end
end
