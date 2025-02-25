RSpec.describe Api::V2::Measures::MeasureConditionSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { create(:measure_condition, :with_guidance, measure_condition_code: 'X') }

  let(:expected_pattern) do
    {
      data: {
        id: serializable.measure_condition_sid.to_s,
        type: 'measure_condition',
        attributes: {
          condition_code: serializable.condition_code,
          condition: serializable.condition,
          document_code: serializable.document_code,
          certificate_description: serializable.certificate_description,
          requirement: serializable.requirement,
          action: nil,
          action_code: serializable.action_code,
          duty_expression: '',
          condition_duty_amount: serializable.condition_duty_amount,
          condition_monetary_unit_code: serializable.condition_monetary_unit_code,
          monetary_unit_abbreviation: nil,
          condition_measurement_unit_code: serializable.condition_measurement_unit_code,
          condition_measurement_unit_qualifier_code: serializable.condition_measurement_unit_qualifier_code,
          measure_condition_class: 'threshold',
          guidance_cds: be_a(String),
          requirement_operator: '>',
          threshold_unit_type: serializable.threshold_unit_type.to_s,
        },
        relationships: {
          measure_condition_components: {
            data: [],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
