RSpec.describe Api::User::SubscriptionTarget::CommoditySerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) do
    build_stubbed(:commodity, goods_nomenclature_sid: 123, goods_nomenclature_item_id: '1234567890').tap do |commodity|
      allow(commodity).to receive_messages(
        id: 123,
        chapter_short_code: '12',
        heading: nil,
        classification_description: 'Live animals; animal products > Live animals > Live horses, asses, mules and hinnies',
        validity_end_date: '2025-12-31',
      )
    end
  end

  let(:expected) do
    {
      data: {
        id: '123',
        type: :commodity,
        attributes: {
          chapter: '12',
          heading: nil,
          goods_nomenclature_item_id: '1234567890',
          classification_description: 'Live animals; animal products > Live animals > Live horses, asses, mules and hinnies',
          validity_end_date: '2025-12-31',
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'serializes commodity with correct structure' do
      expect(serialized).to eq(expected)
    end

    context 'with a null commodity' do
      let(:serializable) do
        PublicUsers::NullCommodity.new(goods_nomenclature_item_id: '9999999999')
      end

      let(:expected) do
        {
          data: {
            id: 'null_9999999999',
            type: :commodity,
            attributes: {
              chapter: nil,
              heading: nil,
              goods_nomenclature_item_id: '9999999999',
              classification_description: '',
              validity_end_date: nil,
            },
          },
        }
      end

      it 'preserves the invalid-code fallback representation' do
        expect(serialized).to eq(expected)
      end
    end
  end
end
