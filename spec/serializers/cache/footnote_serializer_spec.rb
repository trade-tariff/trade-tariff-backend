RSpec.describe Cache::FootnoteSerializer do
  subject(:serialized) { described_class.new(footnote).as_json }

  let(:footnote) { create(:footnote, :with_description) }
  let(:measure_with_goods_nomenclature) { create(:measure, :with_base_regulation, goods_nomenclature: create(:heading, :with_description)) }

  let(:pattern) do
    {
      code: footnote.code,
      footnote_type_id: footnote.footnote_type_id,
      footnote_id: footnote.footnote_id,
      description: footnote.description,
      formatted_description: footnote.formatted_description,
      validity_start_date: footnote.validity_start_date,
      validity_end_date: footnote.validity_end_date,
      goods_nomenclature_ids: [],
      goods_nomenclatures: Array,
      measures: Array,
      measure_ids: [measure_with_goods_nomenclature.measure_sid],
      extra_large_measures: false,
    }
  end

  before do
    measure_no_goods_nomenclature = create(:measure, :with_base_regulation, goods_nomenclature: nil)

    create(:footnote_association_measure, measure: measure_with_goods_nomenclature, footnote:)
    create(:footnote_association_measure, measure: measure_no_goods_nomenclature, footnote:)
  end

  it { is_expected.to match_json_expression(pattern) }
end
