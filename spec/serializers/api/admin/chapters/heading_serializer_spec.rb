RSpec.describe Api::Admin::Chapters::HeadingSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:heading, :with_chapter, :with_descendants) }
  let(:expected) do
    {
      data: {
        id: serializable.goods_nomenclature_sid.to_s,
        type: eq(:heading),
        attributes: {
          goods_nomenclature_sid: serializable.goods_nomenclature_sid,
          goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
          description: serializable.description,
          declarable: serializable.ns_declarable?,
          search_references_count: 0,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to include_json(expected) }
  end
end
