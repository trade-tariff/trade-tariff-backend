RSpec.describe MyCommoditiesSubscriptionWorker, type: :worker do
  subject(:instance) { described_class.new }

  let(:date) { '2025-12-08' }

  describe '#perform' do
    context 'when users have tariff changes on the date' do
      let(:user1) { create(:public_user, :with_my_commodities_subscription) }
      let(:user2) { create(:public_user, :with_my_commodities_subscription) }

      before do
        # Create subscription targets for user1
        subscription1 = PublicUsers::Subscription.where(user_id: user1.id, subscription_type_id: Subscriptions::Type.my_commodities.id).first
        create(:subscription_target, user_subscriptions_uuid: subscription1.uuid, target_id: '1000')
        create(:subscription_target, user_subscriptions_uuid: subscription1.uuid, target_id: '2000')

        # Create subscription targets for user2
        subscription2 = PublicUsers::Subscription.where(user_id: user2.id, subscription_type_id: Subscriptions::Type.my_commodities.id).first
        create(:subscription_target, user_subscriptions_uuid: subscription2.uuid, target_id: '3000')

        # Create tariff changes for the date
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 1000)
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 2000)
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 3000)

        allow(MyCommoditiesEmailWorker).to receive(:perform_async)
      end

      it 'queues email worker for each user with changes' do
        instance.perform(date)

        expect(MyCommoditiesEmailWorker).to have_received(:perform_async).with(user1.id, '08/12/2025', 2)
        expect(MyCommoditiesEmailWorker).to have_received(:perform_async).with(user2.id, '08/12/2025', 1)
      end
    end

    context 'when users have no subscription targets' do
      let(:user) { create(:public_user, :with_my_commodities_subscription) }

      before do
        user
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 1000)
        allow(MyCommoditiesEmailWorker).to receive(:perform_async)
      end

      it 'does not queue emails' do
        instance.perform(date)

        expect(MyCommoditiesEmailWorker).not_to have_received(:perform_async)
      end
    end

    context 'when no tariff changes exist on the date' do
      let(:user) { create(:public_user, :with_my_commodities_subscription) }

      before do
        subscription = PublicUsers::Subscription.where(user_id: user.id, subscription_type_id: Subscriptions::Type.my_commodities.id).first
        create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '1000')
        allow(MyCommoditiesEmailWorker).to receive(:perform_async)
      end

      it 'does not queue any emails' do
        instance.perform(date)

        expect(MyCommoditiesEmailWorker).not_to have_received(:perform_async)
      end
    end

    context 'when multiple tariff changes match the same user target' do
      let(:user) { create(:public_user, :with_my_commodities_subscription) }

      before do
        subscription = PublicUsers::Subscription.where(user_id: user.id, subscription_type_id: Subscriptions::Type.my_commodities.id).first
        create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '1000')

        # Create multiple tariff changes on the same date with same goods_nomenclature_sid
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 1000)
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 1000)
        create(:tariff_change, operation_date: date, goods_nomenclature_sid: 1000)

        allow(MyCommoditiesEmailWorker).to receive(:perform_async)
      end

      it 'counts all matching tariff changes' do
        instance.perform(date)

        expect(MyCommoditiesEmailWorker).to have_received(:perform_async).with(user.id, '08/12/2025', 3)
      end
    end

    context 'when user does not have active subscription' do
      let(:user) { create(:public_user) }

      before do
        allow(MyCommoditiesEmailWorker).to receive(:perform_async)
      end

      it 'does not queue emails' do
        instance.perform(date)

        expect(MyCommoditiesEmailWorker).not_to have_received(:perform_async)
      end
    end
  end
end
