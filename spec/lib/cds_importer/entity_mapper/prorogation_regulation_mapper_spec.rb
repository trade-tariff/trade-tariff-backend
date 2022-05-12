RSpec.describe CdsImporter::EntityMapper::ProrogationRegulationMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'approvedFlag' => '1',
        'publishedDate' => '1998-04-01T00:00:00',
        'informationText' => '474 LPQ-TEXT-RU',
        'officialjournalPage' => '52',
        'replacementIndicator' => '0',
        'officialjournalNumber' => 'L 100',
        'prorogationRegulationId' => 'R9807290',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '5',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        prorogation_regulation_id: 'R9807290',
        prorogation_regulation_role: 5,
        published_date: Date.parse('1998-04-01'),
        officialjournal_number: 'L 100',
        officialjournal_page: 52,
        replacement_indicator: 0,
        information_text: '474 LPQ-TEXT-RU',
        approved_flag: true,
      }
    end

    let(:expected_entity_class) { 'ProrogationRegulation' }
    let(:expected_mapping_root) { 'ProrogationRegulation' }
  end
end
