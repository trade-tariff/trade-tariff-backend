RSpec.describe CdsImporter::EntityMapper::RegulationRoleTypeDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'regulationRoleTypeId' => '1',
        'regulationRoleTypeDescription' => {
          'description' => 'Base regulation',
          'language' => {
            'languageId' => 'EN',
          },
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
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        regulation_role_type_id: '1',
        description: 'Base regulation',
        language_id: 'EN',
      }
    end

    let(:expected_entity_class) { 'RegulationRoleTypeDescription' }
    let(:expected_mapping_root) { 'RegulationRoleType' }
  end
end
