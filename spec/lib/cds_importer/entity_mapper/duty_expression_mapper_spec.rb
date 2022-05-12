RSpec.describe CdsImporter::EntityMapper::DutyExpressionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'dutyExpressionId' => '14',
        'validityEndDate' => '1995-06-30T23:59:59',
        'validityStartDate' => '1972-01-01T00:00:00',
        'dutyAmountApplicabilityCode' => '2',
        'measurementUnitApplicabilityCode' => '0',
        'monetaryUnitApplicabilityCode' => '0',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:10',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1972-01-01T00:00:00.000Z',
        validity_end_date: '1995-06-30T23:59:59.000Z',
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        duty_expression_id: '14',
        duty_amount_applicability_code: 2,
        measurement_unit_applicability_code: 0,
        monetary_unit_applicability_code: 0,
      }
    end

    let(:expected_entity_class) { 'DutyExpression' }
    let(:expected_mapping_root) { 'DutyExpression' }
  end
end
