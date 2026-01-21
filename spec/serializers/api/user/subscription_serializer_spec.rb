RSpec.describe Api::User::SubscriptionSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  context 'when my_commodities subscription' do
    let(:subscription_type) { create(:subscription_type, name: 'my_commodities') }
    let(:serializable) { create(:user_subscription, subscription_type:, metadata: { commodity_codes: %w[1234567890 1234567891] }) }

    let(:expected) do
      {
        data: {
          id: serializable.uuid.to_s,
          type: :subscription,
          attributes: {
            active: true,
            meta: {
              counts: { active: 0, expired: 0, invalid: 2, total: 2 },
              published: { yesterday: 0 },
            },
          },
          relationships: {
            subscription_type: {
              data: {
                id: subscription_type.id.to_s,
                type: :subscription_type,
              },
            },
          },
        },
      }
    end

    describe '#serializable_hash' do
      it {
        expect(serialized).to eq(expected)
      }
    end
  end

  context 'when stop_press subscription' do
    let(:subscription_type) { create(:subscription_type, name: 'stop_press') }
    let(:serializable) { create(:user_subscription, subscription_type:) }

    let(:expected) do
      {
        data: {
          id: serializable.uuid.to_s,
          type: :subscription,
          attributes: {
            active: true,
            meta: {
              chapters: 'all',
              published: { yesterday: 0 },
            },
          },
          relationships: {
            subscription_type: {
              data: {
                id: subscription_type.id.to_s,
                type: :subscription_type,
              },
            },
          },
        },
      }
    end

    describe '#serializable_hash' do
      it {
        expect(serialized).to eq(expected)
      }
    end
  end
end
