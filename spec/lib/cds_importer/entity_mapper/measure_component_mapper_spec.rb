RSpec.describe CdsImporter::EntityMapper::MeasureComponentMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measureComponent' => [
          {
            'dutyAmount' => '12.34',
            'dutyExpression' => { 'dutyExpressionId' => '01' },
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
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        measure_sid: 12_348,
        duty_expression_id: '01',
        duty_amount: 12.34,
        monetary_unit_code: 'EUR',
        measurement_unit_code: 'DTN',
        measurement_unit_qualifier_code: '56',
      }
    end

    let(:expected_entity_class) { 'MeasureComponent' }
    let(:expected_mapping_root) { 'Measure' }
  end
end
