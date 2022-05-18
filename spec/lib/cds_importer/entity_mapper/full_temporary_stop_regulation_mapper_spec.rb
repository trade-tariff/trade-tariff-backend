RSpec.describe CdsImporter::EntityMapper::FullTemporaryStopRegulationMapper do
  it_behaves_like 'an entity mapper', 'FullTemporaryStopRegulation', 'FullTemporaryStopRegulation' do
    let(:xml_node) do
      {
        'sid' => '1277',
        'approvedFlag' => '1',
        'fullTemporaryStopRegulationId' => '22113',
        'publishedDate' => '2017-08-25T07:41:22',
        'effectiveEndDate' => '2018-08-20T09:42:12',
        'officialjournalNumber' => 'K 320',
        'officialjournalPage' => '12',
        'replacementIndicator' => '2',
        'informationText' => 'ER',
        'explicitAbrogationRegulation' => {
          'explicitAbrogationRegulationId' => '11226',
          'regulationRoleType' => {
            'regulationRoleTypeId' => '7',
          },
        },
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
        'ftsRegulationAction' => {
          'sid' => '1127',
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: nil,
        validity_end_date: nil,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        full_temporary_stop_regulation_role: 6,
        full_temporary_stop_regulation_id: '22113',
        published_date: Date.parse('2017-08-25'),
        officialjournal_number: 'K 320',
        officialjournal_page: 12,
        effective_enddate: Date.parse('2018-08-20'),
        explicit_abrogation_regulation_role: 7,
        explicit_abrogation_regulation_id: '11226',
        replacement_indicator: 2,
        information_text: 'ER',
        approved_flag: true,
      }
    end
  end
end
