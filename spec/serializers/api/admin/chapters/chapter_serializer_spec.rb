RSpec.describe Api::Admin::Chapters::ChapterSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { create(:chapter, :with_heading, :with_section) }

  let(:expected) do
    {
      data: {
        id: serializable.goods_nomenclature_sid.to_s,
        type: eq(:chapter),
        attributes: {
          goods_nomenclature_sid: serializable.goods_nomenclature_sid,
          goods_nomenclature_item_id: serializable.goods_nomenclature_item_id,
          producline_suffix: serializable.producline_suffix,
          headings_to: serializable.headings_to,
          headings_from: serializable.headings_from,
          chapter_note_id: nil,
          description: serializable.description,
          section_id: serializable.section_id,
        },
        relationships: {
          section: be_a(Hash),
          headings: be_a(Hash),
          chapter_note: be_a(Hash),
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to include_json(expected) }
  end
end
