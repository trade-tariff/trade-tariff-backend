RSpec.describe Api::User::SubscriptionServiceResolver do
  describe '.batcher_for' do
    context 'when the subscription type is my_commodities' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.my_commodities.id) }

      it 'returns the my commodities batcher service' do
        expect(described_class.batcher_for(subscription)).to eq(Api::User::BatcherService::MyCommoditiesBatcherService)
      end
    end

    context 'when the subscription type is unsupported' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.stop_press.id) }

      it 'raises an unsupported batcher error' do
        expect { described_class.batcher_for(subscription) }
          .to raise_error(described_class::UnsupportedBatcherError, /Unsupported subscription type for batching: stop_press/)
      end
    end
  end

  describe '.filter_for' do
    context 'when the subscription type is my_commodities' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.my_commodities.id) }
      let(:filter_service) { instance_double(Api::User::TargetsFilterService::MyCommoditiesTargetsFilterService) }

      before do
        allow(Api::User::TargetsFilterService::MyCommoditiesTargetsFilterService)
          .to receive(:new)
          .with(subscription)
          .and_return(filter_service)
      end

      it 'returns the my commodities filter service for the subscription' do
        expect(described_class.filter_for(subscription)).to eq(filter_service)
      end
    end

    context 'when the subscription type is unsupported' do
      let(:subscription) { create(:user_subscription, subscription_type_id: Subscriptions::Type.stop_press.id) }

      it 'raises an unsupported filter error' do
        expect { described_class.filter_for(subscription) }
          .to raise_error(described_class::UnsupportedFilterError, /Unsupported subscription type for targets filtering: stop_press/)
      end
    end
  end
end
