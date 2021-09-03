describe Api::V2::Headings::DeclarableHeadingSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    Api::V2::Headings::DeclarableHeadingPresenter.new(
      heading,
      measures,
    )
  end

  let(:heading) { create(:heading, :with_description) }
  let(:measures) { [] }

  let(:chapter) do
    create(
      :chapter,
      :with_section,
      :with_description,
      goods_nomenclature_item_id: heading.chapter_id,
    )
    heading.reload
  end

  let(:expected_pattern) do
    {
      'data' => {
        'id' => heading.goods_nomenclature_sid.to_s,
        'type' => 'heading',
        'attributes' => {
          'validity_start_date' => '2019-09-03T00:00:00.000Z',
          'validity_end_date' => nil,
          'goods_nomenclature_item_id' => heading.goods_nomenclature_item_id,
          'description' => heading.description,
          'bti_url' => 'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code',
          'formatted_description' => heading.formatted_description,
          'basic_duty_rate' => nil,
          'meursing_code' => false,
          'declarable' => true,
        },
        'relationships' => {
          'footnotes' => { 'data' => [] },
          'section' => { 'data' => { 'id' => heading.section_id.to_s, 'type' => 'section' } },
          'chapter' => { 'data' => { 'id' => heading.chapter.goods_nomenclature_sid.to_s, 'type' => 'chapter' } },
          'import_measures' => { 'data' => [] },
          'export_measures' => { 'data' => [] },
        },
      },
    }
  end

  before { chapter }

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
