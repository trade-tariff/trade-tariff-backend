RSpec.describe CdsImporter::EntityMapper::MeasureTypeMapper do
  it_behaves_like 'an entity mapper', 'MeasureType', 'MeasureType' do
    let(:xml_node) do
      {
        'measureTypeId' => '487',
        'validityStartDate' => '1970-01-01T00:00:00',
        'tradeMovementCode' => '0',
        'priorityCode' => '1',
        'measureComponentApplicableCode' => '1',
        'originDestCode' => '0',
        'orderNumberCaptureCode' => '2',
        'measureExplosionLevel' => '10',
        'measureTypeSeries' => {
          'measureTypeSeriesId' => 'M',
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1970-01-01T00:00:00.000Z',
        validity_end_date: nil,
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        measure_type_id: '487',
        trade_movement_code: 0,
        priority_code: 1,
        measure_component_applicable_code: 1,
        origin_dest_code: 0,
        order_number_capture_code: 2,
        measure_explosion_level: 10,
        measure_type_series_id: 'M',
      }
    end
  end
end
