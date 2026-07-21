RSpec.describe Api::User::MyCommoditiesMetaService do
  let!(:subscription_data) do
    subscription = create(
      :user_subscription,
      subscription_type_id: Subscriptions::Type.my_commodities.id,
      metadata: { 'commodity_codes' => %w[1234567890 1234567891 9999999999] },
    )
    active = create(:commodity, :actual, goods_nomenclature_item_id: '1234567890')
    expired = create(:commodity, :expired, goods_nomenclature_item_id: '1234567891')

    [active, expired].each do |commodity|
      create(
        :subscription_target,
        user_subscriptions_uuid: subscription.uuid,
        target_id: commodity.goods_nomenclature_sid,
        target_type: 'commodity',
      )
    end

    { subscription: }
  end

  let(:active_commodities_result) do
    {
      active: %w[1234567890],
      moved: [],
      expired: %w[1234567891],
      invalid: %w[9999999999],
      total: 3,
    }
  end

  let(:expected) do
    {
      counts: {
        active: %w[1234567890],
        moved: [],
        expired: %w[1234567891],
        invalid: %w[9999999999],
        total: 3,
      },
      published: {
        yesterday: 0,
        last_change_date: nil,
      },
    }
  end

  let(:service) { described_class.new(subscription_data[:subscription]) }

  before do
    service_double = instance_double(Api::User::ActiveCommoditiesService, call: active_commodities_result)
    allow(Api::User::ActiveCommoditiesService)
      .to receive(:new)
      .and_return(service_double)
  end

  describe '#call' do
    it { expect(service.call).to eq(expected) }
  end
end
