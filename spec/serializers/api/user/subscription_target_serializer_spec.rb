RSpec.describe Api::User::SubscriptionTargetSerializer do
  subject(:serialized) { described_class.new(subscription_targets, include: [:target_object]).serializable_hash }

  let(:commodity) do
    create(:commodity, goods_nomenclature_item_id: '1234567890',
                       goods_nomenclature_sid: 456,
                       description: 'Commodity 1234567890',
                       validity_end_date: '2022-01-01',
                       heading: create(:heading, description: 'Heading 1'),
                       chapter: create(:chapter, description: 'Chapter 12'))
  end

  let(:subscription_target_with_commodity) do
    PublicUsers::SubscriptionTarget.new(
      target_type: 'commodity',
      commodity: commodity,
    )
  end

  let(:subscription_targets) { [subscription_target_with_commodity] }

  describe '#serializable_hash' do
    context 'when the target includes a commodity' do
      let(:expected) do
        {
          data: [
            {
              id: nil,
              type: :subscription_target,
              relationships: {
                target_object: {
                  data: {
                    id: commodity.goods_nomenclature_sid.to_s,
                    type: :commodity,
                  },
                },
              },
            },
          ],
          included: [
            {
              id: commodity.goods_nomenclature_sid.to_s,
              type: :commodity,
              attributes: {
                classification_description: commodity.classification_description,
                goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                validity_end_date: commodity.validity_end_date,
                chapter: commodity.chapter_short_code,
                heading: commodity.heading&.description,
              },
            },
          ],
        }
      end

      it 'matches the expected serialized structure' do
        expect(serialized).to eq(expected)
      end
    end
  end
end
