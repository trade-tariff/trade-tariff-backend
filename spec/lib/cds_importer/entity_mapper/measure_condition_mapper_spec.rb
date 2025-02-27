RSpec.describe CdsImporter::EntityMapper::MeasureConditionMapper do
  it_behaves_like 'an entity mapper', 'MeasureCondition', 'Measure' do
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
            'monetaryUnit' => { 'monetaryUnitCode' => 'EUR' },
            'measurementUnit' => { 'measurementUnitCode' => 'DTN' },
            'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => '56' },
            'measureAction' => { 'actionCode' => '36' },
            'certificate' => {
              'certificateCode' => '03',
              'certificateType' => {
                'certificateTypeCode' => '05',
              },
            },
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
        measure_condition_sid: 3321,
        condition_code: nil,
        component_sequence_number: 123,
        condition_duty_amount: 12.34,
        condition_monetary_unit_code: 'EUR',
        condition_measurement_unit_code: 'DTN',
        condition_measurement_unit_qualifier_code: '56',
        action_code: '36',
        certificate_type_code: '05',
        certificate_code: '03',
      }
    end
  end
end
