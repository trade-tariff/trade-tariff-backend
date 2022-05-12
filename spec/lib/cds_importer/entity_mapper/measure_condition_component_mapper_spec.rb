RSpec.describe CdsImporter::EntityMapper::MeasureConditionComponentMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measureCondition' => [
          {
            'sid' => '3321',
            'conditionDutyAmount' => '12.34',
            'conditionSequenceNumber' => '123',
            'measureConditionComponent' => [
              {
                'dutyExpression' => { 'dutyExpressionId' => '01' },
                'dutyAmount' => '23.1',
                'monetaryUnit' => { 'monetaryUnitCode' => 'USD' },
                'measurementUnit' => { 'measurementUnitCode' => 'ASD' },
                'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => '12' },
                'metainfo' => {
                  'opType' => 'C',
                  'transactionDate' => '2017-06-29T20:04:37',
                },
              },
            ],
            'monetaryUnit' => { 'monetaryUnitCode' => 'EUR' },
            'measurementUnit' => { 'measurementUnitCode' => 'DTN' },
            'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => '56' },
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2017-06-29T20:04:37',
            },
          },
        ],
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2017-06-29'),
        measure_condition_sid: 3321,
        duty_expression_id: '01',
        duty_amount: 23.1,
        monetary_unit_code: 'USD',
        measurement_unit_code: 'ASD',
        measurement_unit_qualifier_code: '12',
      }
    end

    let(:expected_entity_class) { 'MeasureConditionComponent' }
    let(:expected_mapping_root) { 'Measure' }
  end
end
