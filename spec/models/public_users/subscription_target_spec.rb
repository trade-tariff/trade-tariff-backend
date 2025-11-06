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

  describe '#target' do
    context 'when target_type is commodity' do
      let(:commodity) { create(:commodity, goods_nomenclature_sid: 12_345) }
      let(:subscription_target) { create(:subscription_target, target_type: 'commodity', target_id: commodity.goods_nomenclature_sid) }

      it 'returns the associated commodity' do
        expect(subscription_target.target).to eq(commodity)
      end

      context 'when commodity does not exist' do
        let(:subscription_target) { create(:subscription_target, target_type: 'commodity', target_id: 99_999) }

        it 'returns nil' do
          expect(subscription_target.target).to be_nil
        end
      end
    end

    context 'when target_type is other' do
      let(:subscription_target) { create(:subscription_target, target_type: 'other', target_id: 123) }

      it 'returns nil' do
        expect(subscription_target.target).to be_nil
      end
    end
  end
end
