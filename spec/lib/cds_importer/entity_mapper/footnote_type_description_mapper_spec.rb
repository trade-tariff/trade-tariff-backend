RSpec.describe CdsImporter::EntityMapper::FootnoteTypeDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'footnoteTypeId' => 'TN',
        'footnoteTypeDescription' => {
          'description' => 'Taric Nomenclature',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'transactionDate' => '2016-07-27T09:18:51',
          },
        },
      }
    end

    let(:expected_values) do
      {
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        footnote_type_id: 'TN',
        language_id: 'EN',
        description: 'Taric Nomenclature',
      }
    end

    let(:expected_entity_class) { 'FootnoteTypeDescription' }
    let(:expected_mapping_root) { 'FootnoteType' }
  end
end
