RSpec.describe CdsImporter::EntityMapper::RegulationGroupDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'hjid' => '440103',
        'regulationGroupId' => '123',
        'regulationGroupDescription' => {
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
        regulation_group_id: '123',
        language_id: 'EN',
        description: nil,
      }
    end

    let(:expected_entity_class) { 'RegulationGroupDescription' }
    let(:expected_mapping_root) { 'RegulationGroup' }
  end
end
