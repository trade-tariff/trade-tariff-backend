RSpec.describe StopPressSubscriptionWorker, type: :worker do
  subject(:instance) { described_class.new }

  let(:stop_press) { create(:news_item) }
  let(:user) { create(:public_user, :with_active_stop_press_subscription) }

  describe '#perform' do
    it 'returns users with active stop press subscriptions matching chapters', :aggregate_failures do
      allow(stop_press).to receive_messages(emailable?: true, chapters: '01, 02')
      allow(PublicUsers::User).to receive_messages(active: PublicUsers::User, with_active_stop_press_subscription: PublicUsers::User)
      allow(PublicUsers::User).to receive(:matching_chapters).with(%w[01 02]).and_return(PublicUsers::User)
      allow(News::Item).to receive(:find).and_return(stop_press)

      instance.perform(stop_press.id)

      expect(PublicUsers::User).to have_received(:with_active_stop_press_subscription)
      expect(PublicUsers::User).to have_received(:matching_chapters).with(%w[01 02])
    end

    it 'queues emails' do
      allow(stop_press).to receive_messages(emailable?: true, chapters: '01')
      allow(PublicUsers::User).to receive(:with_active_stop_press_subscription).and_return(PublicUsers::User)
      allow(PublicUsers::User).to receive(:matching_chapters).with(%w[01]).and_return([user])
      allow(News::Item).to receive(:find).and_return(stop_press)
      allow(StopPressEmailWorker).to receive(:perform_async)

      instance.perform(stop_press.id)

      expect(StopPressEmailWorker).to have_received(:perform_async).with(stop_press.id, user.id)
    end
  end
end
