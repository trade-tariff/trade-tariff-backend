RSpec.describe Api::User::SubscriptionTargetSerializer do
  subject(:serialized) { described_class.new(subscription_targets).serializable_hash }

  let(:commodity) do
    OpenStruct.new(
      goods_nomenclature_item_id: '1234567890',
      hierarchical_description: 'Test commodity description',
    )
  end

  let(:commodity_target) do
    OpenStruct.new(
      target_type: 'commodity',
      target_id: 123,
      id: 456,
      target: commodity,
    )
  end

  let(:subscription_targets) { [commodity_target] }

  describe '#serializable_hash' do
    before do
      commodity_serializer_output = {
        data: {
          id: '456',
          type: :commodity,
          attributes: {
            hierarchical_description: 'Test commodity description',
          },
        },
      }

      commodity_serializer = instance_double(Api::User::SubscriptionTarget::CommoditySerializer)
      allow(commodity_serializer).to receive(:serializable_hash).and_return(commodity_serializer_output)
      allow(Api::User::SubscriptionTarget::CommoditySerializer).to receive(:new).with(commodity).and_return(commodity_serializer)
    end

    context 'when targets include commodity type' do
      it 'delegates to the CommoditySerializer' do
        commodity_serializer = instance_double(Api::User::SubscriptionTarget::CommoditySerializer)
        allow(commodity_serializer).to receive(:serializable_hash).and_return({ data: {} })
        allow(Api::User::SubscriptionTarget::CommoditySerializer).to receive(:new).with(commodity).and_return(commodity_serializer)

        serialized
        expect(Api::User::SubscriptionTarget::CommoditySerializer).to have_received(:new).with(commodity)
      end

      it 'returns the serialized data in correct format' do
        result = serialized
        expect(result).to have_key(:data)
        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(1)
      end
    end

    context 'when targets is empty' do
      let(:subscription_targets) { [] }

      it 'returns empty data array' do
        expect(serialized).to eq({ data: [] })
      end
    end

    context 'when constantize fails for unknown type' do
      let(:unknown_target) do
        OpenStruct.new(
          target_type: 'unknown_type',
          target_id: 999,
          id: 888,
          target: OpenStruct.new(id: 999),
        )
      end
      let(:subscription_targets) { [unknown_target] }

      it 'raises NameError for unrecognized target type' do
        expect { serialized }.to raise_error(NameError)
      end
    end
  end
end
