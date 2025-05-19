RSpec.describe PublicUsers::User do
  let(:user) { create(:public_user) }

  describe 'associations' do
    it 'has a subscriptions association' do
      t = described_class.association_reflections[:subscriptions]
      expect(t[:type]).to eq(:one_to_many)
    end

    it 'has a preferences association' do
      t = described_class.association_reflections[:preferences]
      expect(t[:type]).to eq(:one_to_one)
    end
  end

  describe 'when creating' do
    it 'creates a preferences record' do
      expect(user.preferences).not_to be_nil
    end
  end

  describe 'email attribute' do
    it 'has a settable virtual email attribute' do
      user.email = 'example@test.com'
      expect(user.email).to eq 'example@test.com'
    end
  end

  describe '#stop_press_subscription' do
    it 'returns true when user has an active subscription' do
      user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: true)
      expect(user.stop_press_subscription).to be true
    end

    it 'returns false when user has an inactive subscription' do
      user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: false)
      expect(user.stop_press_subscription).to be false
    end

    it 'returns false when user does not have a subscription' do
      expect(user.stop_press_subscription).to be false
    end
  end

  describe '#stop_press_subscription=' do
    context 'when user has subscription' do
      before do
        user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: true)
      end

      context 'when value is true' do
        it 'enables the subscription' do
          user.stop_press_subscription = true
          expect(user.stop_press_subscription).to be true
        end
      end

      context 'when value is false' do
        it 'disables the subscription' do
          user.stop_press_subscription = false
          expect(user.stop_press_subscription).to be false
        end
      end
    end

    context 'when user has no subscription' do
      context 'when value is true' do
        it 'enables the subscription' do
          user.stop_press_subscription = true
          expect(user.stop_press_subscription).to be true
        end
      end

      context 'when value is false' do
        it 'disables the subscription' do
          user.stop_press_subscription = false
          expect(user.stop_press_subscription).to be false
        end
      end
    end
  end
end
