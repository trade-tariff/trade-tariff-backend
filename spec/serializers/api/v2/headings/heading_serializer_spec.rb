RSpec.describe Api::V2::Headings::HeadingSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { Api::V2::Headings::HeadingPresenter.new(heading) }

  let(:heading) do
    create(
      :heading,
      :non_grouping,
      :non_declarable,
      :with_description,
    )
  end

  let(:chapter) do
    create(
      :chapter,
      :with_section,
      :with_description,
      goods_nomenclature_item_id: heading.chapter_id,
    )
  end

  let(:actual_date) { Time.zone.today }

  let(:expected_pattern) do
    {
      data: {
        id: heading.goods_nomenclature_sid.to_s,
        type: 'heading',
        attributes: {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          description: heading.description,
          bti_url: 'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code',
          formatted_description: heading.formatted_description,
          declarable: false,
        },
        relationships: {
          footnotes: { data: [] },
          section: { data: nil },
          chapter: { data: nil },
          commodities: { data: [{ id: heading.commodities.first.goods_nomenclature_sid.to_s, type: 'commodity' }] },
        },
      },
    }
  end

  before { chapter }

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
