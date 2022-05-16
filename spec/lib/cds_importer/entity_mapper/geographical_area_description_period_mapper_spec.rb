RSpec.describe CdsImporter::EntityMapper::GeographicalAreaDescriptionPeriodMapper do
  it_behaves_like 'an entity mapper', 'GeographicalAreaDescriptionPeriod', 'GeographicalArea' do
    let(:xml_node) do
      {
        'sid' => '234',
        'geographicalAreaId' => '1032',
        'geographicalAreaDescriptionPeriod' => {
          'sid' => '1239',
          'validityStartDate' => '2008-01-01T00:00:00',
          'validityEndDate' => nil,
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
        validity_start_date: Time.zone.parse('2008-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        geographical_area_description_period_sid: 1239,
        geographical_area_sid: 234,
        geographical_area_id: '1032',
      }
    end
  end
end
