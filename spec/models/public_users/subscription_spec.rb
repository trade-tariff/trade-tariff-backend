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
end
