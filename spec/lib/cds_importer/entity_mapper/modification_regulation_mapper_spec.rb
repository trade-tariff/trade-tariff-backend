RSpec.describe CdsImporter::EntityMapper::ModificationRegulationMapper do
  it_behaves_like 'an entity mapper', 'ModificationRegulation', 'ModificationRegulation' do
    let(:xml_node) do
      {
        'modificationRegulationId' => 'R9617341',
        'publishedDate' => '1996-09-19T00:00:00',
        'officialjournalNumber' => 'L 238',
        'officialjournalPage' => '1',
        'replacementIndicator' => '0',
        'stoppedFlag' => '1',
        'approvedFlag' => '1',
        'informationText' => 'NC - 01.01.1997 (mes. 110/111)',
        'effectiveEndDate' => '1996-06-30T23:59:59',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '2019-03-03T00:00:00',
        'regulationRoleType' => { 'regulationRoleTypeId' => '5' },
        'baseRegulation' => {
          'baseRegulationId' => 'R8726581',
          'regulationRoleType' => { 'regulationRoleTypeId' => '8' },
        },
        'explicitAbrogationRegulation' => {
          'explicitAbrogationRegulationId' => '321',
          'regulationRoleType' => { 'regulationRoleTypeId' => '7' },
        },
        'completeAbrogationRegulation' => {
          'completeAbrogationRegulationId' => '123',
          'regulationRoleType' => { 'regulationRoleTypeId' => '6' },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1970-01-01T00:00:00.000Z',
        validity_end_date: '2019-03-03T00:00:00.000Z',
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        modification_regulation_id: 'R9617341',
        published_date: Date.parse('1996-09-19'),
        officialjournal_number: 'L 238',
        officialjournal_page: 1,
        base_regulation_id: 'R8726581',
        replacement_indicator: 0,
        information_text: 'NC - 01.01.1997 (mes. 110/111)',
        effective_end_date: Time.zone.parse('1996-06-30T23:59:59.000Z'),
        approved_flag: true,
        stopped_flag: true,
        modification_regulation_role: 5,
        base_regulation_role: 8,
        explicit_abrogation_regulation_role: 7,
        explicit_abrogation_regulation_id: '321',
        complete_abrogation_regulation_role: 6,
        complete_abrogation_regulation_id: '123',
      }
    end
  end
end
