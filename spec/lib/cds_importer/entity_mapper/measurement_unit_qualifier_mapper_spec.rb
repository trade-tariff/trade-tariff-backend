RSpec.describe CdsImporter::EntityMapper::MeasurementUnitQualifierMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'measurementUnitQualifierCode' => 'B',
        'validityStartDate' => '1970-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        measurement_unit_qualifier_code: 'B',
      }
    end

    let(:expected_entity_class) { 'MeasurementUnitQualifier' }
    let(:expected_mapping_root) { 'MeasurementUnitQualifier' }
  end
end
