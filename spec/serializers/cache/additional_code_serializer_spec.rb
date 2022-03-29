RSpec.describe Cache::AdditionalCodeSerializer do
  subject(:serialized) { described_class.new(additional_code.reload).as_json }

  before do
    included_measure
    excluded_measure_goods_nomenclature
    excluded_measure_bad_dates
  end

  let(:additional_code) do
    code = create(:additional_code)

    create(:additional_code_description, :with_period, additional_code_sid: code.additional_code_sid)

    code
  end

  let(:included_measure) do
    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      goods_nomenclature: create(:heading, :with_description),
    )
  end

  let(:excluded_measure_goods_nomenclature) do
    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      goods_nomenclature: nil,
    )
  end

  let(:excluded_measure_bad_dates) do
    create(
      :measure,
      :with_base_regulation,
      additional_code_sid: additional_code.additional_code_sid,
      validity_end_date: Time.zone.yesterday,
    )
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
      measure_ids: [included_measure.measure_sid],
      measures: Array,
    }
  end

  it { is_expected.to match_json_expression(pattern) }
end
