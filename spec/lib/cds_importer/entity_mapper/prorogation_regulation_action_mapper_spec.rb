RSpec.describe CdsImporter::EntityMapper::ProrogationRegulationActionMapper do
  it_behaves_like 'an entity mapper', 'ProrogationRegulationAction', 'ProrogationRegulation' do
    let(:xml_node) do
      {
        'prorogationRegulationId' => 'C123X324',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '4',
        },
        'prorogationRegulationAction' => {
          'prorogatedDate' => '1998-04-01T00:00:00',
          'prorogatedRegulationId' => 'P423X824',
          'prorogatedRegulationRole' => '1',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        prorogation_regulation_role: 4,
        prorogation_regulation_id: 'C123X324',
        prorogated_regulation_role: 1,
        prorogated_regulation_id: 'P423X824',
        prorogated_date: Date.parse('1998-04-01'),
      }
    end
  end
end
