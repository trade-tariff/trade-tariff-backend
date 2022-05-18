RSpec.describe CdsImporter::EntityMapper::MeasurePartialTemporaryStopMapper do
  it_behaves_like 'an entity mapper', 'MeasurePartialTemporaryStop', 'Measure' do
    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measurePartialTemporaryStop' => {
          'sid' => '22134',
          'validityStartDate' => '1971-03-03T00:00:00',
          'validityEndDate' => '2018-02-01T00:00:00',
          'partialTemporaryStopRegulationId' => 'R1312020',
          'partialTemporaryStopRegulationOfficialjournalNumber' => 'L 321',
          'partialTemporaryStopRegulationOfficialjournalPage' => '1',
          'abrogationRegulationId' => 'R1312021',
          'abrogationRegulationOfficialjournalNumber' => 'L 323',
          'abrogationRegulationOfficialjournalPage' => '2',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-25T21:03:21',
          },
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
        validity_start_date: Time.zone.parse('1971-03-03T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('2018-02-01T00:00:00.000Z'),
        operation: 'U',
        operation_date: Date.parse('2017-07-25'),
        measure_sid: 12_348,
        partial_temporary_stop_regulation_id: 'R1312020',
        partial_temporary_stop_regulation_officialjournal_number: 'L 321',
        partial_temporary_stop_regulation_officialjournal_page: 1,
        abrogation_regulation_id: 'R1312021',
        abrogation_regulation_officialjournal_number: 'L 323',
        abrogation_regulation_officialjournal_page: 2,
      }
    end
  end
end
