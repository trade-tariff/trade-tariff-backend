RSpec.describe PublicUsers::UserDeletionService do
  before { allow(ExternalUserDeletionWorker).to receive(:perform_async) }

  describe '.soft_delete' do
    context 'when the user is soft deleted' do
      let(:user) { create(:public_user) }

      it 'starts the external deletion worker once for the user' do
        described_class.soft_delete(user)

        expect(ExternalUserDeletionWorker).to have_received(:perform_async).with(user.id).once
      end
    end

    context 'when the user still has an active subscription' do
      let(:user) { create(:public_user) }

      before { user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: true) }

      it 'does not start the worker' do
        described_class.soft_delete(user)

        expect(ExternalUserDeletionWorker).not_to have_received(:perform_async)
      end
    end

    context 'when the user is already deleted' do
      let(:user) { create(:public_user, deleted: true) }

      it 'does not start the worker' do
        described_class.soft_delete(user)

        expect(ExternalUserDeletionWorker).not_to have_received(:perform_async)
      end
    end
  end

  describe '.invalidate' do
    let(:user) { create(:public_user) }

    before { create(:user_subscription, user_id: user.id, subscription_type_id: Subscriptions::Type.stop_press.id, active: true) }

    it 'invalidates the subscriptions and starts the worker once' do
      described_class.invalidate(user)

      expect(user.refresh.deleted).to be(true)
      expect(ExternalUserDeletionWorker).to have_received(:perform_async).with(user.id).once
    end
  end

  describe '.unsubscribe' do
    let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.stop_press.id) }

    it 'unsubscribes and starts the worker once for the subscription user' do
      described_class.unsubscribe(subscription)

      expect(subscription.reload.active).to be(false)
      expect(ExternalUserDeletionWorker).to have_received(:perform_async).with(subscription.user.id).once
    end

    context 'when the user has another active subscription' do
      before { create(:user_subscription, user_id: subscription.user_id, subscription_type_id: Subscriptions::Type.my_commodities.id, active: true) }

      it 'does not start the worker' do
        described_class.unsubscribe(subscription)

        expect(ExternalUserDeletionWorker).not_to have_received(:perform_async)
      end
    end
  end
end
