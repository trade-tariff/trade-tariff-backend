RSpec.describe Api::User::SubscriptionTarget::CommoditySerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) do
    build_stubbed(:commodity, goods_nomenclature_sid: 123, goods_nomenclature_item_id: '1234567890').tap do |commodity|
      allow(commodity).to receive_messages(
        id: 123,
        classification_description: 'Live animals; animal products > Live animals > Live horses, asses, mules and hinnies',
      )
    end
  end

  let(:expected) do
    {
      data: {
        id: '123',
        type: :commodity,
        attributes: {
          goods_nomenclature_item_id: '1234567890',
          classification_description: 'Live animals; animal products > Live animals > Live horses, asses, mules and hinnies',
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'serializes commodity with correct structure' do
      expect(serialized).to eq(expected)
    end

    it 'includes classification_description attribute' do
      expect(serialized[:data][:attributes]).to include(:classification_description)
    end

    it 'sets the correct type' do
      expect(serialized[:data][:type]).to eq(:commodity)
    end

    it 'uses id as the identifier' do
      expect(serialized[:data][:id]).to eq('123')
    end
  end
end
