RSpec.describe Api::User::SubscriptionTargetSerializer do
  subject(:serialized) { described_class.new(subscription_targets).serializable_hash }

  let(:commodity) { create(:commodity, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 456) }

  let(:subscription_target_with_commodity) do
    PublicUsers::SubscriptionTarget.new(
      virtual_id: commodity.goods_nomenclature_sid,
      target_type: 'commodity',
      commodity:,
    )
  end

  let(:subscription_targets) { [subscription_target_with_commodity] }

  describe '#serializable_hash' do
    context 'when the target includes a commodity' do
      let(:expected) do
        {
          data: [
            {
              id: commodity.goods_nomenclature_sid.to_s,
              type: :subscription_target,
              attributes: {
                target_type: 'commodity',
                chapter_short_code: commodity.chapter_short_code,
                goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                classification_description: commodity.classification_description,
                producline_suffix: commodity.producline_suffix,
                validity_end_date: commodity.validity_end_date,
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
