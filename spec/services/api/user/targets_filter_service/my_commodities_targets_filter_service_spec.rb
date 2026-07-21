RSpec.describe Api::User::TargetsFilterService::MyCommoditiesTargetsFilterService do
  let(:subscription) { create(:user_subscription, subscription_type: Subscriptions::Type.my_commodities) }
  let(:service) { described_class.new(subscription) }

  let(:active_commodities_service) { instance_double(Api::User::ActiveCommoditiesService) }

  before do
    allow(Api::User::ActiveCommoditiesService)
      .to receive(:new)
      .with(subscription)
      .and_return(active_commodities_service)
  end

  describe '#call' do
    context 'when filter is nil' do
      let!(:subscription_targets) do
        [
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '123'),
          create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: '456'),
        ]
      end

      it 'returns existing subscription targets' do
        targets, total = service.call(nil, 1, 20)
        expect(targets.map(&:id)).to match_array(subscription_targets.map(&:id))
        expect(total).to eq(2)
      end
    end

    context 'when filter is active' do
      let(:first_commodity) { create(:commodity, goods_nomenclature_sid: 123) }
      let(:second_commodity) { create(:commodity, goods_nomenclature_sid: 456) }

      before do
        allow(active_commodities_service).to receive(:respond_to?)
          .with('active_commodities')
          .and_return(true)

        allow(active_commodities_service)
          .to receive(:active_commodities)
          .with(page: 1, per_page: 20)
          .and_return([[first_commodity, second_commodity], 2])
      end

      it 'maps commodities into subscription targets' do
        targets, total = service.call(:active, 1, 20)

        expect(total).to eq(2)
        expect(targets.first.target_type).to eq('commodity')
        expect(targets.first.commodity).to eq(first_commodity)
      end
    end

    context 'when filter does not exist' do
      before do
        allow(active_commodities_service).to receive(:respond_to?)
          .and_return(false)
      end

      it 'returns empty results' do
        targets, total = service.call(:not_a_real_filter, 1, 20)
        expect(targets).to eq([])
        expect(total).to eq(0)
      end
    end
  end
end
