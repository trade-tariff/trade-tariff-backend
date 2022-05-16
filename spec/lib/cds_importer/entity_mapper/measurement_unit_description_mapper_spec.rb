RSpec.describe CdsImporter::EntityMapper::MeasurementUnitDescriptionMapper do
  it_behaves_like 'an entity mapper', 'MeasurementUnitDescription', 'MeasurementUnit' do
    let(:xml_node) do
      {
        'measurementUnitCode' => 'MWH',
        'measurementUnitDescription' => {
          'description' => '1000 kilowatt hours',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2017-06-29'),
        measurement_unit_code: 'MWH',
        language_id: 'EN',
        description: '1000 kilowatt hours',
      }
    end
  end
end
