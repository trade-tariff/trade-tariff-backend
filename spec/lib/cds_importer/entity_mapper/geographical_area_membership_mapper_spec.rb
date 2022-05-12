RSpec.describe CdsImporter::EntityMapper::GeographicalAreaMembershipMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'hjid' => '123',
        'sid' => '234',
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-08-29T20:14:17',
        },
        'geographicalAreaMembership' => {
          'hjid' => '25864',
          'geographicalAreaGroupSid' => '461273',
          'geographicalAreaSid' => '311',
          'validityStartDate' => '2008-01-01T00:00:00',
          'validityEndDate' => '2020-06-29T20:04:37',
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('2008-01-01T00:00:00.000Z'),
        validity_end_date: Time.parse('2020-06-29T20:04:37.000Z'),
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        hjid: 25_864,
        geographical_area_group_sid: 461_273,
        geographical_area_sid: 311,
      }
    end

    let(:expected_entity_class) { 'GeographicalAreaMembership' }
    let(:expected_mapping_root) { 'GeographicalArea' }
  end
end
