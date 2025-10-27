RSpec.describe PublicUsers::SubscriptionTarget do
  describe '.scope' do
    describe '.commodities' do
      let(:subscription) { create(:user_subscription) }

      before do
        create(:subscription_target, target_type: 'commodity', target_id: 123)
        create(:subscription_target, target_type: 'measure', target_id: 456)
      end

      it 'returns only commodity targets' do
        expect(described_class.commodities.count).to eq(1)
        expect(described_class.commodities.first.target_id).to eq(123)
      end
    end
  end
end
