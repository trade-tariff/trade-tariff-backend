RSpec.describe CdsImporter::EntityMapper::RegulationRoleTypeMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'regulationRoleTypeId' => '1',
        'validityStartDate' => '1970-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1970-01-01T00:00:00.000Z',
        validity_end_date: nil,
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        regulation_role_type_id: 1,
      }
    end

    let(:expected_entity_class) { 'RegulationRoleType' }
    let(:expected_mapping_root) { 'RegulationRoleType' }
  end
end
