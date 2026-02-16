RSpec.describe GovukNotifierStatusCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:user) { create(:public_user, :with_my_commodities_subscription, :with_active_stop_press_subscription) }
  let(:notification_id) { SecureRandom.uuid }
  let(:notifier) { instance_double(GovukNotifier) }
  let(:status) { 'delivered' }

  before do
    allow(GovukNotifier).to receive(:new).and_return(notifier)
    allow(notifier).to receive(:get_email_status).and_return(status)
  end

  context 'when notification id is blank' do
    it 'does nothing' do
      worker.perform(user.id, nil)

      expect(notifier).not_to have_received(:get_email_status)
      expect(user.subscriptions_dataset.where(active: true).count).to eq(2)
      expect(user.refresh.deleted).to be(false)
    end
  end

  context 'when user does not exist' do
    it 'does nothing' do
      worker.perform(999_999, notification_id)

      expect(notifier).not_to have_received(:get_email_status)
    end
  end

  context 'when status is not permanent failure' do
    it 'does not modify subscriptions or user' do
      worker.perform(user.id, notification_id)

      expect(user.subscriptions_dataset.where(active: true).count).to eq(2)
      expect(user.refresh.deleted).to be(false)
    end
  end

  context 'when status is permanent failure' do
    let(:status) { GovukNotifier::PERMANENT_FAILURE }

    it 'unsubscribes all active subscriptions and soft deletes the user' do
      worker.perform(user.id, notification_id)

      expect(user.subscriptions_dataset.where(active: true).count).to eq(0)
      expect(user.refresh.deleted).to be(true)
    end
  end
end
