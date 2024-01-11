RSpec.describe Api::V2::SearchReferenceSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { create(:search_reference) }

    let(:expected_pattern) do
      {
        data: {
          id: serializable.id.to_s,
          type: :search_reference,
          attributes: {
            title: serializable.title,
            negated_title: serializable.title_indexed,
            referenced_id: serializable.referenced_id,
            referenced_class: 'Heading',
            goods_nomenclature_sid: serializable.goods_nomenclature_sid,
            goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
            productline_suffix: '80',
          },
        },
      }
    end

    it { is_expected.to eq(expected_pattern) }
  end
end
