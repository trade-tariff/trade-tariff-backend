RSpec.describe GovukNotifierStatusCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:user) { create(:public_user, :with_my_commodities_subscription, :with_active_stop_press_subscription) }
  let(:notification_id) { SecureRandom.uuid }
  let(:checker) { instance_double(Notifications::DeliveryStatusChecker, call: nil) }

  before do
    allow(Notifications::DeliveryStatusChecker).to receive(:new).and_return(checker)
  end

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end

  context 'when notification id is blank' do
    it 'does nothing' do
      worker.perform(user.id, nil)

      expect(Notifications::DeliveryStatusChecker).not_to have_received(:new)
      expect(user.subscriptions_dataset.where(active: true).count).to eq(2)
      expect(user.refresh.deleted).to be(false)
    end
  end

  context 'when user does not exist' do
    it 'does nothing' do
      worker.perform(999_999, notification_id)

      expect(Notifications::DeliveryStatusChecker).not_to have_received(:new)
    end
  end

  context 'when checker returns nil (non-failure status)' do
    it 'does not modify subscriptions or user' do
      allow(checker).to receive(:call).and_return(nil)

      worker.perform(user.id, notification_id)

      expect(user.subscriptions_dataset.where(active: true).count).to eq(2)
      expect(user.refresh.deleted).to be(false)
    end
  end

  context 'when checker returns permanent-failure' do
    it 'unsubscribes all active subscriptions and soft deletes the user' do
      allow(checker).to receive(:call).and_return(GovukNotifier::PERMANENT_FAILURE)

      worker.perform(user.id, notification_id)

      expect(user.subscriptions_dataset.where(active: true).count).to eq(0)
      expect(user.refresh.deleted).to be(true)
    end
  end

  it 'delegates to DeliveryStatusChecker with the my_ott pipeline' do
    worker.perform(user.id, notification_id)

    expect(Notifications::DeliveryStatusChecker).to have_received(:new).with(
      notification_id,
      pipeline: 'my_ott',
      identifier: user.id,
    )
  end
end
