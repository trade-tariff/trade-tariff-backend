RSpec.describe CdsImporter::EntityMapper::LanguageDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'languageId' => 'EN',
        'languageDescription' => {
          'description' => 'English',
          'language' => 'EN',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2017-06-29'),
        language_code_id: 'EN',
        language_id: 'EN',
        description: 'English',
      }
    end

    let(:expected_entity_class) { 'LanguageDescription' }
    let(:expected_mapping_root) { 'Language' }
  end
end
