RSpec.describe PublicUsers::SubscriptionTarget do
  describe '#add_targets_for_subscription' do
    let(:subscription) { create(:user_subscription) }
    let(:user) { subscription.user }
    let(:targets) do
      [create(:goods_nomenclature, goods_nomenclature_sid: 123),
       create(:goods_nomenclature, goods_nomenclature_sid: 456)]
    end
    let(:existing_targets) do
      [create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 789, target_type: 'commodity'),
       create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 321, target_type: 'commodity'),
       create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 999, target_type: 'measure')]
    end

    context 'when there is an array of targets and a subscription' do
      before do
        existing_targets.each(&:save)
        described_class.add_targets_for_subscription(subscription: subscription, targets: targets, target_type: 'commodity')
      end

      it 'only deletes existing targets for the selected subscription type' do
        target_ids = subscription.subscription_targets_dataset.map(&:target_id)

        expect(target_ids).not_to include(789, 321)
        expect(target_ids).to include(999)
      end

      it 'adds the target sids for the subscription type' do
        expect(subscription.subscription_targets_dataset.commodities.map(&:target_id))
       .to match_array(targets.map(&:goods_nomenclature_sid))
      end
    end

    context 'when there are no targets' do
      let(:targets) { [] }

      before do
        described_class.add_targets_for_subscription(subscription: subscription, targets: targets, target_type: 'commodity')
      end

      it 'does not add any targets' do
        expect(subscription.subscription_targets.count).to eq(0)
      end
    end

    context 'when there are no subscriptions' do
      let(:subscription) { nil }

      it 'raises an error' do
        expect {
          described_class.add_targets_for_subscription(subscription: nil, targets: targets, target_type: 'commodity')
        }.to raise_error(ArgumentError, 'subscription must be present')
      end
    end
  end

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
