RSpec.describe CdsImporter::EntityMapper::MeasureTypeSeriesMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'measureTypeSeriesId' => 'N',
        'validityStartDate' => '1970-01-01T00:00:00',
        'measureTypeCombination' => '1',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1970-01-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        measure_type_series_id: 'N',
        measure_type_combination: 1,
      }
    end

    let(:expected_entity_class) { 'MeasureTypeSeries' }
    let(:expected_mapping_root) { 'MeasureTypeSeries' }
  end
end
