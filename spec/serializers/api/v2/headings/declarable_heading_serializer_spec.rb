RSpec.describe Api::V2::Headings::DeclarableHeadingSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    Api::V2::Headings::DeclarableHeadingPresenter.new(
      heading,
      measures,
    )
  end

  let(:heading) { create(:heading, :with_description) }
  let(:measures) { MeasureCollection.new [] }

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
      data: {
        id: heading.goods_nomenclature_sid.to_s,
        type: 'heading',
        attributes: {
          validity_start_date: heading.validity_start_date.iso8601(3),
          validity_end_date: nil,
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          description: heading.description,
          bti_url: 'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code',
          formatted_description: heading.formatted_description,
          basic_duty_rate: nil,
          meursing_code: true,
          declarable: true,
          has_chemicals: false,
        },
        relationships: {
          footnotes: { data: [] },
          section: { data: { id: heading.section_id.to_s, type: 'section' } },
          chapter: { data: { id: heading.chapter.goods_nomenclature_sid.to_s, type: 'chapter' } },
          import_measures: { data: [] },
          export_measures: { data: [] },
        },
        meta: {
          duty_calculator: {
            applicable_additional_codes: {
              '1' => {
                'type' => 'additional_code',
                'code' => '1999',
                'description' => 'Third country additional duty',
              },
            },
            applicable_measure_units: {
              'DTN' => {
                'measurement_unit_code' => 'DTN',
                'description' => '100 kg',
              },
            },
            applicable_vat_options: {
              'VATZ' => {
                'value' => 'VATZ',
                'description' => 'VAT zero rate',
              },
            },
            entry_price_system: true,
            meursing_code: true,
            source: 'uk',
            trade_defence: true,
            zero_mfn_duty: true,
          },
        },
      },
    }
  end

  before do
    chapter

    allow(serializable).to receive_messages(
      applicable_additional_codes: {
        '1' => {
          'type' => 'additional_code',
          'code' => '1999',
          'description' => 'Third country additional duty',
        },
      },
      applicable_measure_units: {
        'DTN' => {
          'measurement_unit_code' => 'DTN',
          'description' => '100 kg',
        },
      },
      applicable_vat_options: {
        'VATZ' => {
          'value' => 'VATZ',
          'description' => 'VAT zero rate',
        },
      },
      entry_price_system?: true,
      meursing_code: true,
      trade_remedies?: true,
      zero_mfn_duty?: true,
    )
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
