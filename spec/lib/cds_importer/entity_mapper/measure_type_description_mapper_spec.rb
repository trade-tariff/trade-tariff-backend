RSpec.describe CdsImporter::EntityMapper::MeasureTypeDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'measureTypeId' => '487',
        'measureTypeDescription' => {
          'description' => 'Representative price (poultry)',
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
        measure_type_id: '487',
        language_id: 'EN',
        description: 'Representative price (poultry)',
      }
    end

    let(:expected_entity_class) { 'MeasureTypeDescription' }
    let(:expected_mapping_root) { 'MeasureType' }
  end
end
