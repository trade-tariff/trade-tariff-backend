RSpec.describe CdsImporter::EntityMapper::ExplicitAbrogationRegulationMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'regulationRoleType' => { 'regulationRoleTypeId' => '123' },
        'explicitAbrogationRegulationId' => '456',
        'publishedDate' => '2000-01-01',
        'officialjournalNumber' => 6,
        'officialjournalPage' => 2,
        'replacementIndicator' => '0',
        'abrogationDate' => '2000-01-02',
        'informationText' => 'some info',
        'approvedFlag' => true,
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:10',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        explicit_abrogation_regulation_role: 123,
        explicit_abrogation_regulation_id: '456',
        published_date: Date.parse('2000-01-01'),
        officialjournal_number: '6',
        officialjournal_page: 2,
        replacement_indicator: 0,
        abrogation_date: Date.parse('2000-01-02'),
        information_text: 'some info',
        approved_flag: false,
      }
    end

    let(:expected_entity_class) { 'ExplicitAbrogationRegulation' }
    let(:expected_mapping_root) { 'ExplicitAbrogationRegulation' }
  end
end
