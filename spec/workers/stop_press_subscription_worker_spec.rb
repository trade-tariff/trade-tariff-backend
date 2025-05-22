require 'rails_helper'

RSpec.describe StopPressSubscriptionWorker, type: :worker do
  subject(:instance) { described_class.new }

  let(:stop_press) { create(:news_item) }
  let(:user) { create(:public_user, :with_active_stop_press_subscription) }

  describe '#perform' do
    context 'when news item is not emailable' do
      it 'does nothing' do
        allow(stop_press).to receive(:emailable?).and_return(false)
        allow(PublicUsers::User).to receive(:with_active_stop_press_subscription).and_return(PublicUsers::User)

        instance.perform(stop_press.id)

        expect(PublicUsers::User).not_to have_received(:with_active_stop_press_subscription)
      end
    end

    context 'when news item is emailable' do
      it 'returns users with active stop press subscriptions matching chapters', :aggregate_failures do
        allow(stop_press).to receive_messages(emailable?: true, chapters: %w[01 02])
        allow(PublicUsers::User).to receive(:with_active_stop_press_subscription).and_return(PublicUsers::User)
        allow(PublicUsers::User).to receive(:matching_chapters).with(%w[01 02]).and_return(PublicUsers::User)
        allow(News::Item).to receive(:find).and_return(stop_press)

        instance.perform(stop_press.id)

        expect(PublicUsers::User).to have_received(:with_active_stop_press_subscription)
        expect(PublicUsers::User).to have_received(:matching_chapters).with(%w[01 02])
      end
    end
  end
end
