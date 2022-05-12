RSpec.describe CdsImporter::EntityMapper::BaseRegulationMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'hjid' => '11089523',
        'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-02-02T18:02:02' },
        'approvedFlag' => '1',
        'baseRegulationId' => 'X2014790',
        'communityCode' => '1',
        'informationText' => 'The Trade in Torture etc. Goods (Amendment) (EU Exit) Regulations 2020 S.I. 2020/1479 https://www.legislation.gov.uk/uksi/2020/1479',
        'officialjournalNumber' => '1',
        'officialjournalPage' => '1',
        'publishedDate' => '2020-12-10T00:00:00',
        'replacementIndicator' => '0',
        'stoppedFlag' => '0',
        'validityStartDate' => '2021-01-01T00:00:00',
        'regulationGroup' => { 'hjid' => '380', 'regulationGroupId' => 'PRS' },
        'regulationRoleType' => { 'hjid' => '386', 'regulationRoleTypeId' => '1' },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('2021-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'C',
        operation_date: Date.parse('2021-02-02'),
        base_regulation_role: 1,
        base_regulation_id: 'X2014790',
        community_code: 1,
        regulation_group_id: 'PRS',
        replacement_indicator: 0,
        stopped_flag: false,
        approved_flag: true,
        information_text: 'The Trade in Torture etc. Goods (Amendment) (EU Exit) Regulations 2020 S.I. 2020/1479 https://www.legislation.gov.uk/uksi/2020/1479',
        published_date: Date.parse('2020-12-10'),
        officialjournal_number: '1',
        officialjournal_page: 1,
        effective_end_date: nil,
        antidumping_regulation_role: nil,
        related_antidumping_regulation_id: nil,
        complete_abrogation_regulation_role: nil,
        complete_abrogation_regulation_id: nil,
        explicit_abrogation_regulation_role: nil,
        explicit_abrogation_regulation_id: nil,
      }
    end

    let(:expected_entity_class) { 'BaseRegulation' }
    let(:expected_mapping_root) { 'BaseRegulation' }
  end
end
