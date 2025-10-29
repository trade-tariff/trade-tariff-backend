RSpec.describe BatcherService::MyCommoditiesBatcherService do
  let(:my_targets) { %w[1234567890 1234567891 1234567892] }

  let(:existing_targets) do
    [create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 789, target_type: 'commodity'),
     create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 321, target_type: 'commodity'),
     create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 999, target_type: 'measure')]
  end

  describe '#call' do
    context 'when the user has a my commodities subscription' do
      let(:user) { create(:public_user, :with_my_commodities_subscription) }
      let(:subscription) do
        user.subscriptions_dataset
                              .where(subscription_type: Subscriptions::Type.my_commodities)
                              .first
      end

      before do
        existing_targets
        subscription.update(metadata: { 'commodity_codes' => %w[0987654321 1987654321], 'measures' => %w[1234567890 1234567891] })

        create(:commodity, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123)
        create(:commodity, goods_nomenclature_item_id: '1234567891', goods_nomenclature_sid: 456)
        create(:measure, goods_nomenclature_item_id: '1234567892', goods_nomenclature_sid: 789)
        described_class.new.call(my_targets, user)
        subscription.refresh
      end

      it 'updates only the commodity_codes key in metadata' do
        subscription.refresh
        expect(subscription.metadata['commodity_codes']).to match_array(my_targets)
        expect(subscription.metadata['measures']).to match_array(%w[1234567890 1234567891])
      end

      it 'deletes existing commodity targets for the subscription' do
        target_ids = subscription.subscription_targets_dataset.map(&:target_id)

        expect(target_ids).not_to include(789, 321)
        expect(target_ids).to include(999)
      end

      it 'creates subscription_targets with the correct ids and type' do
        targets = subscription.subscription_targets_dataset

        expect(targets.commodities.count).to eq(2)
        expect(targets.commodities.map(&:target_id)).to contain_exactly(123, 456)
      end
    end

    context 'when the user does not have a my commodities subscription' do
      let(:user) { create(:public_user, :with_active_stop_press_subscription) }

      it 'raises an error' do
        expect {
          described_class.new.call(my_targets, user)
        }.to raise_error(ArgumentError, 'my commodities subscription must be present')
      end

      it 'does not write any targets to user subscriptions metadata' do
        expect(user.subscriptions.first.metadata).to be_nil
      end

      it 'does not write any targets to user subscription targets' do
        expect(user.subscriptions.first.subscription_targets.count).to eq(0)
      end
    end
  end
end
