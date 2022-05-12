RSpec.describe CdsImporter::EntityMapper::CompleteAbrogationRegulationMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
        'completeAbrogationRegulationId' => 'R9808461',
        'publishedDate' => '2017-08-27T10:11:12',
        'officialjournalNumber' => 'L 120',
        'officialjournalPage' => '13',
        'replacementIndicator' => '0',
        'informationText' => 'TR',
        'approvedFlag' => '0',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2017-09-22T17:26:25',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2017-09-22'),
        complete_abrogation_regulation_role: 6,
        complete_abrogation_regulation_id: 'R9808461',
        published_date: Date.parse('2017-08-27'),
        officialjournal_number: 'L 120',
        officialjournal_page: 13,
        replacement_indicator: 0,
        information_text: 'TR',
        approved_flag: false,
      }
    end

    let(:expected_entity_class) { 'CompleteAbrogationRegulation' }
    let(:expected_mapping_root) { 'CompleteAbrogationRegulation' }
  end
end
