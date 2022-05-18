RSpec.describe CdsImporter::EntityMapper::GeographicalAreaMapper do
  it_behaves_like 'an entity mapper', 'GeographicalArea', 'GeographicalArea' do
    let(:xml_node) do
      {
        'sid' => '234',
        'hjid' => '123',
        'validityStartDate' => '1984-01-01T00:00:00',
        'validityEndDate' => nil,
        'geographicalCode' => '1',
        'geographicalAreaId' => '1032',
        'parentGeographicalAreaGroupSid' => '400',
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1984-01-01T00:00:00.000Z',
        validity_end_date: nil,
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        hjid: 123,
        geographical_area_sid: 234,
        geographical_code: '1',
        geographical_area_id: '1032',
        parent_geographical_area_group_sid: 400,
      }
    end
  end
end
