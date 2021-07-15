require 'rails_helper'

RSpec.describe Api::V2::Measures::MeasureConditionSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { create(:measure_condition) }

  let(:expected_pattern) do
    {
      "data": {
        "id": serializable.measure_condition_sid.to_s,
        "type": 'measure_condition',
        "attributes": {
          "condition_code": serializable.condition_code,
          "condition": serializable.condition,
          "document_code": serializable.document_code,
          "requirement": serializable.requirement,
          "action": nil,
          "action_code": serializable.action_code,
          "duty_expression": '',
          "condition_duty_amount": serializable.condition_duty_amount,
          "condition_monetary_unit_code": serializable.condition_monetary_unit_code,
          "monetary_unit_abbreviation": nil,
          "condition_measurement_unit_code": serializable.condition_measurement_unit_code,
          "condition_measurement_unit_qualifier_code": serializable.condition_measurement_unit_qualifier_code,
        },
        "relationships": {
          "measure_condition_components": {
            "data": [],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
