RSpec.describe CdsImporter::EntityMapper::LanguageMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'languageId' => 'EN',
        'validityStartDate' => '1992-03-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1992-03-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        language_id: 'EN',
      }
    end

    let(:expected_entity_class) { 'Language' }
    let(:expected_mapping_root) { 'Language' }
  end
end
