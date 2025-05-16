RSpec.describe PublicUsers::Preferences do
  describe 'associations' do
    it 'has a user association' do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)
    end
  end
end
