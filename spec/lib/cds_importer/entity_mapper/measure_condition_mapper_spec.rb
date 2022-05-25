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
          }
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

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('Measure', xml_node) }

    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measureType' => { 'measureTypeId' => '468' },
        'geographicalArea' => { 'sid' => '11881', 'geographicalAreaId' => '1011' },
        'goodsNomenclature' => { 'sid' => '22118', 'goodsNomenclatureItemId' => '0102900500' },
        'measureGeneratingRegulationRole' => { 'regulationRoleTypeId' => '1' },
        'measureGeneratingRegulationId' => 'IYY99990',
        'justificationRegulationRole' => { 'regulationRoleTypeId' => '1' },
        'justificationRegulationId' => 'IYY99990',
        'stoppedFlag' => '0',
        'ordernumber' => '094281',
        'additionalCode' => {
          'sid' => '11822',
          'additionalCodeCode' => '912',
          'additionalCodeType' => { 'additionalCodeTypeId' => '8' },
        },
        'reductionIndicator' => '35',
        'exportRefundNomenclature' => { 'sid' => '19911' },
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
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
                'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => 'A' },
                'metainfo' => {
                  'opType' => 'C',
                  'transactionDate' => '2017-06-29T20:04:37',
                },
              },
            ],
            'monetaryUnit' => { 'monetaryUnitCode' => 'EUR' },
            'measurementUnit' => { 'measurementUnitCode' => 'DTN' },
            'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => 'B' },
            'metainfo' => {
              'opType' => 'C',
              'transactionDate' => '2017-06-29T20:04:37',
            },
          },
        ],
      }
    end

    context 'when there are missing secondary entities to be soft deleted' do
      let(:operation) { 'C' }

      before do
        # Creates entities that will be missing from the xml node
        create(
          :measure_condition,
          :with_measure_condition_components,
          measure_sid: '12348',
          measure_condition_sid: '3321',
          duty_expression_id: '02',
        )
        # Control for non-deleted secondary entities
        create(
          :measure_condition_component,
          measure_condition_sid: '3321',
          duty_expression_id: '01',
        )
      end

      it_behaves_like 'an entity mapper missing destroy operation', MeasureConditionComponent, measure_condition_sid: '3321'
    end
  end
end
