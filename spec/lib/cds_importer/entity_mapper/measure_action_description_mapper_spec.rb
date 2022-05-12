RSpec.describe CdsImporter::EntityMapper::MeasureActionDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'actionCode' => '29',
        'measureActionDescription' => {
          'description' => 'Import/export allowed after control',
          'language' => {
            'languageId' => 'EN',
          },
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
        action_code: '29',
        language_id: 'EN',
        description: 'Import/export allowed after control',
      }
    end

    let(:expected_entity_class) { 'MeasureActionDescription' }
    let(:expected_mapping_root) { 'MeasureAction' }
  end
end
