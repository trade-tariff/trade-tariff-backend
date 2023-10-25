RSpec.describe Api::Admin::Chapters::ChapterListSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:chapter) }

  let(:expected) do
    {
      data: {
        id: serializable.goods_nomenclature_sid.to_s,
        type: :chapter,
        attributes: {
          goods_nomenclature_sid: serializable.goods_nomenclature_sid,
          goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
          producline_suffix: serializable.producline_suffix,
          chapter_note_id: nil,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end
