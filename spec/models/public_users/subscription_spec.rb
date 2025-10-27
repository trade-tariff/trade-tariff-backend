RSpec.describe PublicUsers::Subscription do
  describe 'associations' do
    it 'has the correct associations', :aggregate_failures do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)

      t = described_class.association_reflections[:subscription_type]
      expect(t[:type]).to eq(:many_to_one)
    end
  end

  describe '#unsubscribe' do
    let(:subscription) { create(:user_subscription) }
    let(:user) { subscription.user }

    before do
      allow(PublicUsers::ActionLog).to receive(:create)
      allow(user).to receive(:soft_delete!)
    end

    it 'deactivates the subscription' do
      expect { subscription.unsubscribe }.to change { subscription.reload.active }.from(true).to(false)
    end

    it 'logs the unsubscribe action' do
      subscription.unsubscribe
      expect(PublicUsers::ActionLog).to have_received(:create).with(user_id: user.id, action: PublicUsers::ActionLog::UNSUBSCRIBED)
    end

    it 'soft deletes the user' do
      subscription.unsubscribe
      expect(user).to have_received(:soft_delete!)
    end

    context 'when the subscription is already inactive' do
      before { subscription.update(active: false) }

      it 'does not log an unsubscribe action' do
        subscription.unsubscribe
        expect(PublicUsers::ActionLog).not_to have_received(:create).with(user_id: user.id, action: PublicUsers::ActionLog::UNSUBSCRIBED)
      end
    end
  end

  describe 'metadata accessors' do
    let(:subscription) { create(:user_subscription) }
    let(:metadata) { { commodity_codes: %w[1234567890 1234567891] } }

    it 'allows setting and getting metadata' do
      subscription.metadata = metadata
      expect(subscription.metadata).to eq(metadata.stringify_keys)
    end
  end

  describe '.scope' do
    describe '.with_subscription_type' do
      before do
        create(:public_user, :with_my_commodities_subscription)
        create(:public_user, :with_active_stop_press_subscription)
      end

      it 'returns subscriptions of type my_commodities' do
        expect(described_class.with_subscription_type(Subscriptions::Type.my_commodities).count).to eq(1)
      end
    end
  end

  describe '#add_targets' do
    let(:subscription) { create(:user_subscription) }
    let(:user) { subscription.user }

    context 'when there is an array of targets and a subscription' do
      let(:targets) do
        [create(:goods_nomenclature, goods_nomenclature_sid: 123),
         create(:goods_nomenclature, goods_nomenclature_sid: 456)]
      end
      let(:existing_targets) do
        [create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 789, target_type: 'commodity'),
         create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 321, target_type: 'commodity'),
         create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 999, target_type: 'measure')]
      end

      before do
        existing_targets.each(&:save)
        subscription.add_targets(targets: targets, target_type: 'commodity')
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
        subscription.add_targets(targets: targets, target_type: 'commodity')
      end

      it 'does not add any targets' do
        expect(subscription.subscription_targets.count).to eq(0)
      end
    end
  end
end
