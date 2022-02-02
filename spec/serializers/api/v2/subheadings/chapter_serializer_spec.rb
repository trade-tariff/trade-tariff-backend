RSpec.describe Api::V2::Subheadings::ChapterSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { create(:chapter, :with_description, :with_guide) }

  let(:expected_pattern) do
    {
      data: {
        id: serializable.goods_nomenclature_sid.to_s,
        type: 'chapter',
        attributes: {
          goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
          description: serializable.description,
          formatted_description: serializable.formatted_description,
          chapter_note: serializable.chapter_note,
        },
        relationships: {
          guides: { data: [{ id: serializable.guides.first.id.to_s, type: 'guide' }] },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
