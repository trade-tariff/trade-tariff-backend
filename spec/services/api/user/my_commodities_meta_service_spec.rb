RSpec.describe Api::User::MyCommoditiesMetaService do
  let(:subscription) do
    create(:user_subscription,
           subscription_type_id: Subscriptions::Type.my_commodities.id,
           metadata: { 'commodity_codes' => %w[1234567890 1234567891 9999999999] })
  end

  let(:targets) { %w[1234567890 1234567891 1234567892] }

  let(:expected) do
    {
      active: %w[1234567890],
      moved: [],
      expired: %w[1234567891],
      invalid: %w[9999999999],
    }
  end

  let(:service) { described_class.new(subscription.metadata['commodity_codes'], targets) }

  before do
    service_double = instance_double(Api::User::ActiveCommoditiesService, call: expected)
    allow(Api::User::ActiveCommoditiesService)
      .to receive(:new)
      .and_return(service_double)
  end

  describe '#call' do
    it { expect(service.call).to eq(expected) }
  end
end
