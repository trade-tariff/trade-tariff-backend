RSpec.describe Api::User::MyCommoditiesMetaService do
  let(:subscription) do
    create(:user_subscription,
           subscription_type_id: Subscriptions::Type.my_commodities.id,
           metadata: { 'commodity_codes' => %w[1234567890 1234567891 9999999999] })
  end

  let!(:commodity_active) do
    create(:commodity, :actual,
           goods_nomenclature_item_id: '1234567890')
  end

  let!(:commodity_expired) do
    create(:commodity, :expired,
           goods_nomenclature_item_id: '1234567891')
  end

  let!(:targets) do
    [
      create(:subscription_target,
             user_subscriptions_uuid: subscription.uuid,
             target_id: commodity_active.goods_nomenclature_sid,
             target_type: 'commodity'),
      create(:subscription_target,
             user_subscriptions_uuid: subscription.uuid,
             target_id: commodity_expired.goods_nomenclature_sid,
             target_type: 'commodity'),

    ]
  end

  let(:expected) do
    {
      active: %w[1234567890],
      moved: [],
      expired: %w[1234567891],
      invalid: %w[9999999999],
    }
  end

  let(:service) { described_class.new(subscription) }

  before do
    targets
    service_double = instance_double(Api::User::ActiveCommoditiesService, call: expected)
    allow(Api::User::ActiveCommoditiesService)
      .to receive(:new)
      .and_return(service_double)
  end

  describe '#call' do
    it { expect(service.call).to eq(expected) }
  end
end
