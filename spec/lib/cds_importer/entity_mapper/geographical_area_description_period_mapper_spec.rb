RSpec.describe CdsImporter::EntityMapper::GeographicalAreaDescriptionPeriodMapper do
  let(:xml_node) do
    {
      'hjid' => '23937',
      'metainfo' => {
        'opType' => operation,
        'origin' => 'T',
        'status' => 'L',
        'transactionDate' => '2021-01-29T18:05:33',
      },
      'sid' => '62',
      'geographicalAreaId' => '2005',
      'geographicalCode' => '1',
      'parentGeographicalAreaGroupSid' => '23802',
      'validityStartDate' => '1997-01-01T00:00:00',
      'geographicalAreaDescriptionPeriod' => [
        {
          'hjid' => '11078014',
          'metainfo' => {
            'opType' => operation,
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2021-01-29T18:05:33',
          },
          'sid' => '1429',
          'validityStartDate' => '2021-01-01T00:00:00',
        },
      ],
      'geographicalAreaMembership' => [
        {
          'hjid' => '25624',
          'metainfo' => {
            'opType' => operation,
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T04:15:45',
          },
          'geographicalAreaGroupSid' => '23588',
          'validityStartDate' => '1997-01-01T00:00:00',
        },
      ],
      'filename' => 'foo.gzip',
    }
  end

  let(:operation) { 'U' }

  it_behaves_like 'an entity mapper', 'GeographicalAreaDescriptionPeriod', 'GeographicalArea' do
    let(:expected_values) do
      {
        validity_start_date: '2021-01-01T00:00:00.000Z',
        validity_end_date: nil,
        national: false,
        operation: 'U',
        operation_date: Date.parse('2021-01-29'),
        geographical_area_description_period_sid: 1429,
        geographical_area_sid: 62,
        geographical_area_id: '2005',
      }
    end
  end
end
