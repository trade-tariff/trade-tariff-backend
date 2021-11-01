RSpec.describe Api::V2::Commodities::CommoditySerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { Api::V2::Commodities::CommodityPresenter.new(commodity, measures) }
  let(:commodity) { create(:commodity, :with_heading, :with_chapter, :with_description).reload }
  let(:measures) { [] }

  let(:expected_pattern) do
    {
      data: {
        id: commodity.goods_nomenclature_sid.to_s,
        type: 'commodity',
        attributes: {
          producline_suffix: '80',
          description: commodity.description,
          number_indents: 1,
          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          bti_url: 'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code',
          formatted_description: commodity.formatted_description,
          description_plain: commodity.description_plain,
          consigned: false,
          consigned_from: nil,
          basic_duty_rate: nil,
          meursing_code: false,
          declarable: true,
        },
        relationships: {
          footnotes: { data: [] },
          section: { data: {} },
          chapter: { data: {} },
          heading: { data: {} },
          ancestors: { data: [] },
          import_measures: { data: [] },
          export_measures: { data: [] },
        },
        meta: {
          duty_calculator: {
            applicable_additional_codes: {},
            applicable_measure_units: {},
            applicable_vat_options: {},
            entry_price_system: false,
            meursing_code: false,
            source: 'uk',
            trade_defence: false,
            zero_mfn_duty: false,
          },
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
