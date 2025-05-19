RSpec.describe PublicUsers::Subscription do
  describe 'associations' do
    it 'has the correct associations', :aggregate_failures do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)

      t = described_class.association_reflections[:subscription_type]
      expect(t[:type]).to eq(:many_to_one)
    end
  end
end
