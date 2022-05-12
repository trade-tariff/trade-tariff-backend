RSpec.describe CdsImporter::EntityMapper::MeasureMapper do
  it_behaves_like 'an entity mapper' do
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
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.parse('1972-01-01T00:00:00.000Z'),
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        measure_sid: 12_348,
        measure_type_id: '468',
        geographical_area_id: '1011',
        geographical_area_sid: 11_881,
        goods_nomenclature_item_id: '0102900500',
        goods_nomenclature_sid: 22_118,
        measure_generating_regulation_role: 1,
        measure_generating_regulation_id: 'IYY99990',
        justification_regulation_role: 1,
        justification_regulation_id: 'IYY99990',
        stopped_flag: false,
        ordernumber: '094281',
        additional_code_type_id: '8',
        additional_code_id: '912',
        additional_code_sid: 11_822,
        reduction_indicator: 35,
        export_refund_nomenclature_sid: 19_911,
      }
    end

    let(:expected_entity_class) { 'Measure' }
    let(:expected_mapping_root) { 'Measure' }
  end
end
