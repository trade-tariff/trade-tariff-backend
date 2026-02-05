RSpec.describe Api::User::TargetsFilterService::MyCommoditiesTargetsFilterService do
  let(:subscription) { create(:user_subscription, subscription_type: Subscriptions::Type.my_commodities) }
  let(:service) { described_class.new(subscription) }

  let(:commodity1) { create(:commodity, goods_nomenclature_sid: 123) }
  let(:commodity2) { create(:commodity, goods_nomenclature_sid: 456) }

  let(:active_commodities_service) { instance_double(Api::User::ActiveCommoditiesService) }

  before do
    allow(Api::User::ActiveCommoditiesService)
      .to receive(:new)
      .with(subscription)
      .and_return(active_commodities_service)
  end

  describe '#call' do
    context 'when filter is nil' do
      let(:filter_type) { nil }

      let!(:subscription_targets) do
        [
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '123'),
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '456'),
        ]
      end

      it 'returns existing subscription targets' do
        targets, total = service.call(filter_type, 1, 20)
        expect(targets.map(&:id)).to match_array(subscription_targets.map(&:id))
        expect(total).to eq(2)
      end
    end

    context 'when filter is active' do
      let(:filter_type) { :active }

      before do
        allow(active_commodities_service).to receive(:respond_to?)
          .with('active_commodities')
          .and_return(true)

        allow(active_commodities_service)
          .to receive(:active_commodities)
          .with(page: 1, per_page: 20)
          .and_return([[commodity1, commodity2], 2])
      end

      it 'maps commodities into subscription targets' do
        targets, total = service.call(filter_type, 1, 20)

        expect(total).to eq(2)
        expect(targets.first.target_type).to eq('commodity')
        expect(targets.first.commodity).to eq(commodity1)
      end
    end

    context 'when filter does not exist' do
      let(:filter_type) { :not_a_real_filter }

      before do
        allow(active_commodities_service).to receive(:respond_to?)
          .and_return(false)
      end

      it 'returns empty results' do
        targets, total = service.call(filter_type, 1, 20)
        expect(targets).to eq([])
        expect(total).to eq(0)
      end
    end
  end
end
