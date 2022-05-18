RSpec.describe CdsImporter::EntityMapper::MeasureExcludedGeographicalAreaMapper do
  it_behaves_like 'an entity mapper', 'MeasureExcludedGeographicalArea', 'Measure' do
    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measureType' => {
          'measureTypeId' => '468',
        },
        'measureExcludedGeographicalArea' => {
          'geographicalArea' => {
            'sid' => '11993',
            'geographicalAreaId' => '1101',
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2017-07-15T22:27:51',
            },
          },
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-14T21:34:15',
          },
        },
        'geographicalArea' => {
          'sid' => '11881',
          'geographicalAreaId' => '1011',
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
        operation: 'U',
        operation_date: Date.parse('2017-07-14'),
        measure_sid: 12_348,
        excluded_geographical_area: '1101',
        geographical_area_sid: 11_993,
      }
    end
  end
end
