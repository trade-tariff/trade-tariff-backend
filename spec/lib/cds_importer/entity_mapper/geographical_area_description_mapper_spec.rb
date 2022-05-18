RSpec.describe CdsImporter::EntityMapper::GeographicalAreaDescriptionMapper do
  it_behaves_like 'an entity mapper', 'GeographicalAreaDescription', 'GeographicalArea' do
    let(:xml_node) do
      {
        'sid' => '234',
        'geographicalAreaId' => '1032',
        'geographicalAreaDescriptionPeriod' => {
          'sid' => '1239',
          'geographicalAreaDescription' => {
            'description' => 'Economic Partnership Agreements',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'opType' => 'U',
              'origin' => 'N',
              'transactionDate' => '2016-07-27T09:21:40',
            },
          },
        },
      }
    end

    let(:expected_values) do
      {
        national: true,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        geographical_area_description_period_sid: 1239,
        language_id: 'EN',
        geographical_area_sid: 234,
        geographical_area_id: '1032',
        description: 'Economic Partnership Agreements',
      }
    end
  end
end
