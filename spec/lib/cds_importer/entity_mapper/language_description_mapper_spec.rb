RSpec.describe CdsImporter::EntityMapper::LanguageDescriptionMapper do
  it_behaves_like 'an entity mapper', 'LanguageDescription', 'Language' do
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
  end
end
