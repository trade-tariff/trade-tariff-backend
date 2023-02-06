RSpec.describe Api::Admin::Headings::HeadingSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:serializable) { Api::Admin::Headings::HeadingPresenter.new(heading, counts) }
  let(:heading) { create(:heading, :with_chapter, :with_descendants).reload }
  let(:counts) { { heading.goods_nomenclature_sid => 12 } }
  let(:expected) do
    {
      data: {
        id: heading.goods_nomenclature_sid.to_s,
        type: eq(:heading),
        attributes: {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          description: heading.description,
          search_references_count: 12,
        },
        relationships: {
          chapter: {
            data: {
              id: heading.chapter.goods_nomenclature_sid.to_s,
              type: eq(:chapter),
            },
          },
          commodities: {
            data: [
              { id: match(/\d+{10}-\d{2}/), type: eq(:commodity) },
              { id: match(/\d+{10}-\d{2}/), type: eq(:commodity) },
            ],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to include_json(expected) }
  end
end
