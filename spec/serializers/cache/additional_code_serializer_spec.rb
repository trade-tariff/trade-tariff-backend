RSpec.describe Cache::AdditionalCodeSerializer do
  subject(:serialized) { described_class.new(additional_code.reload, []).as_json }

  let(:additional_code) do
    code = create(:additional_code)

    create(:additional_code_description, :with_period, additional_code_sid: code.additional_code_sid)

    code
  end

  let(:pattern) do
    {
      additional_code_sid: additional_code.additional_code_sid,
      code: additional_code.code,
      additional_code_type_id: String,
      additional_code: String,
      description: String,
      formatted_description: String,
      validity_start_date: Time,
      validity_end_date: nil,
      measure_ids: all(be_a(Integer)),
      measures: Array,
    }
  end

  before do
    current_goods_nomenclature = create(:heading, :with_description)
    non_current_goods_nomenclature = create(
      :heading,
      :with_description,
      validity_end_date: Time.zone.yesterday,
    )

    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      goods_nomenclature_sid: current_goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_item_id: current_goods_nomenclature.goods_nomenclature_item_id,
    )
    create(
      :measure,
      :with_unapproved_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      goods_nomenclature_sid: current_goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_item_id: current_goods_nomenclature.goods_nomenclature_item_id,
    )

    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      goods_nomenclature_sid: nil,
      goods_nomenclature_item_id: nil,
    )
    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      validity_end_date: Time.zone.yesterday,
      goods_nomenclature_sid: current_goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_item_id: current_goods_nomenclature.goods_nomenclature_item_id,
    )
    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      validity_end_date: nil,
      goods_nomenclature_sid: non_current_goods_nomenclature.goods_nomenclature_sid,
      goods_nomenclature_item_id: non_current_goods_nomenclature.goods_nomenclature_item_id,
    )
  end

  it { is_expected.to match_json_expression(pattern) }
end
