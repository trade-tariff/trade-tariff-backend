RSpec.describe Api::Admin::Headings::HeadingSerializer do
  subject(:serialized) { described_class.new(serializable).serializable_hash }

  let(:heading) { create(:heading, :with_chapter, :non_declarable).reload }
  let(:counts) { { heading.twelvedigit => 12 } }
  let(:serializable) { Api::Admin::Headings::HeadingPresenter.new(heading, counts) }

  let(:expected) do
    {
      data: {
        id: heading.goods_nomenclature_sid.to_s,
        type: :heading,
        attributes: {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          description: heading.description,
          search_references_count: 12,
        },
        relationships: {
          chapter: {
            data: {
              id: heading.chapter.goods_nomenclature_sid.to_s,
              type: :chapter,
            },
          },
          commodities: {
            data: heading.commodities.map do |c|
              {
                id: c.twelvedigit,
                type: :commodity,
              }
            end,
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { expect(serialized).to eq(expected) }
  end
end
