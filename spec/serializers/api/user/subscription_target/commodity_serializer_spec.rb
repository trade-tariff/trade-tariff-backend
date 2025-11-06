RSpec.describe Api::User::SubscriptionTarget::CommoditySerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) do
    build_stubbed(:commodity, goods_nomenclature_sid: 123).tap do |commodity|
      allow(commodity).to receive_messages(
        id: 123,
        hierarchical_description: 'Live animals; animal products > Live animals > Live horses, asses, mules and hinnies',
      )
    end
  end

  let(:expected) do
    {
      data: {
        id: '123',
        type: :commodity,
        attributes: {
          hierarchical_description: 'Live animals; animal products > Live animals > Live horses, asses, mules and hinnies',
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'serializes commodity with correct structure' do
      expect(serialized).to eq(expected)
    end

    it 'includes hierarchical_description attribute' do
      expect(serialized[:data][:attributes]).to include(:hierarchical_description)
    end

    it 'sets the correct type' do
      expect(serialized[:data][:type]).to eq(:commodity)
    end

    it 'uses id as the identifier' do
      expect(serialized[:data][:id]).to eq('123')
    end
  end

  context 'when hierarchical_description is nil' do
    let(:serializable) do
      build_stubbed(:commodity, goods_nomenclature_sid: 456).tap do |commodity|
        allow(commodity).to receive_messages(
          id: 456,
          hierarchical_description: nil,
        )
      end
    end

    let(:expected) do
      {
        data: {
          id: '456',
          type: :commodity,
          attributes: {
            hierarchical_description: nil,
          },
        },
      }
    end

    it 'handles nil hierarchical_description gracefully' do
      expect(serialized).to eq(expected)
    end
  end
end
