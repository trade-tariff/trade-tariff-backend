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
    describe '.with_my_commodities_subscription' do
      before do
        create(:public_user, :with_my_commodities_subscription)
        create(:public_user, :with_active_stop_press_subscription)
      end

      it 'returns subscriptions of type my_commodities' do
        expect(described_class.with_my_commodities_subscription.count).to eq(1)
      end
    end
  end
end
