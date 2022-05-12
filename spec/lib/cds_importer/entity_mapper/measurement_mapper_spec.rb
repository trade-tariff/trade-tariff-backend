RSpec.describe CdsImporter::EntityMapper::MeasurementMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'measurementUnitCode' => 'DDS',
        'validityStartDate' => '1971-02-11T00:00:00',
        'validityEndDate' => '1972-01-04T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-07-29T20:04:37',
        },
        'measurementUnitQualifier' => {
          'measurementUnitQualifierCode' => 'X',
        },
      }
    end

    let(:expected_values) do
      {
        measurement_unit_code: 'DDS',
        measurement_unit_qualifier_code: 'X',
        validity_start_date: Time.parse('1971-02-11T00:00:00.000Z'),
        validity_end_date: Time.parse('1972-01-04T00:00:00.000Z'),
        operation: 'C',
        operation_date: Date.parse('2017-07-29'),
      }
    end

    let(:expected_entity_class) { 'Measurement' }
    let(:expected_mapping_root) { 'MeasurementUnit' }
  end
end
