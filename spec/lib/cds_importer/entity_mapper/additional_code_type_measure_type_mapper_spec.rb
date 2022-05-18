RSpec.describe CdsImporter::EntityMapper::AdditionalCodeTypeMeasureTypeMapper do
  it_behaves_like 'an entity mapper', 'AdditionalCodeTypeMeasureType', 'AdditionalCodeType' do
    let(:xml_node) do
      {
        'additionalCodeTypeId' => '3',
        'additionalCodeTypeMeasureType' => {
          'validityStartDate' => '1999-09-01T00:00:00',
          'measureType' => {
            'measureTypeId' => '468',
          },
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'N',
            'transactionDate' => '2016-07-22T20:03:35',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1999-09-01T00:00:00.000Z',
        validity_end_date: nil,
        national: true,
        operation: 'C',
        operation_date: Date.parse('2016-07-22'),
        measure_type_id: '468',
        additional_code_type_id: '3',
      }
    end
  end
end
