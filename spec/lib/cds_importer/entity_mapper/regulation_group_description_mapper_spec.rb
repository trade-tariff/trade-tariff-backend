RSpec.describe CdsImporter::EntityMapper::RegulationGroupDescriptionMapper do
  it_behaves_like 'an entity mapper', 'RegulationGroupDescription', 'RegulationGroup' do
    let(:xml_node) do
      {
        'hjid' => '440103',
        'regulationGroupId' => '123',
        'regulationGroupDescription' => {
          'description' => 'A regulation group',
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
        description: 'A regulation group',
      }
    end
  end
end
