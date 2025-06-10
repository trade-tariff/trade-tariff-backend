RSpec.describe Api::User::SubscriptionSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:user_subscription) }

  let(:expected) do
    {
      data: {
        id: serializable.uuid.to_s,
        type: :subscription,
        attributes: {
          active: true,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end
