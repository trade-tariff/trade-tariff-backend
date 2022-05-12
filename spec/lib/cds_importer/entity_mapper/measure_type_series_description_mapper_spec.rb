RSpec.describe CdsImporter::EntityMapper::MeasureTypeSeriesDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'measureTypeSeriesId' => 'N',
        'measureTypeSeriesDescription' => {
          'description' => 'Posterior surveillance',
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
        measure_type_series_id: 'N',
        language_id: 'EN',
        description: 'Posterior surveillance',
      }
    end

    let(:expected_entity_class) { 'MeasureTypeSeriesDescription' }
    let(:expected_mapping_root) { 'MeasureTypeSeries' }
  end
end
