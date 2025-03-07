RSpec.describe Api::V2::Measures::MeasureConditionComponentSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(measure_condition_component).serializable_hash }

    let(:measure_condition_component) do
      create(
        :measure_condition_component,
        duty_expression_id: duty_expression.duty_expression_id,
        duty_amount: 10.0,
        monetary_unit_code: 'foo',
        measurement_unit_code: 'bar',
        measurement_unit_qualifier_code: 'a',
      )
    end

    let(:duty_expression) { create(:duty_expression, :with_description) }

    let(:expected_pattern) do
      {
        data: {
          id: measure_condition_component.pk.join('-'),
          type: :measure_condition_component,
          attributes: {
            duty_expression_id: duty_expression.duty_expression_id,
            duty_amount: 10.0,
            monetary_unit_code: 'foo',
            monetary_unit_abbreviation: nil,
            measurement_unit_code: 'bar',
            duty_expression_description: duty_expression.description,
            duty_expression_abbreviation: nil,
            measurement_unit_qualifier_code: 'a',
            measure_condition_sid: be_a(Integer),
          },
        },
      }
    end

    it { is_expected.to include(expected_pattern) }
  end
end
