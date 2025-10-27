RSpec.describe Api::User::SubscriptionSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:user_subscription, metadata: %w[1234567890 1234567891]) }

  let(:expected) do
    {
      data: {
        id: serializable.uuid.to_s,
        type: :subscription,
        attributes: {
          active: true,
          metadata: %w[1234567890 1234567891],
          subscription_type: 'test',
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end
