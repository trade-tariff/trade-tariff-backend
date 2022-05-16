RSpec.describe CdsImporter::EntityMapper::MeasurementUnitQualifierDescriptionMapper do
  it_behaves_like 'an entity mapper', 'MeasurementUnitQualifierDescription', 'MeasurementUnitQualifier' do
    let(:xml_node) do
      {
        'measurementUnitQualifierCode' => 'B',
        'measurementUnitQualifierDescription' => {
          'description' => 'per flask',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2016-07-27T09:20:17',
          },
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        measurement_unit_qualifier_code: 'B',
        description: 'per flask',
        language_id: 'EN',
      }
    end
  end
end
