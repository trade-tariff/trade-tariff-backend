RSpec.describe CdsImporter::EntityMapper::MeasureConditionCodeDescriptionMapper do
  it_behaves_like 'an entity mapper', 'MeasureConditionCodeDescription', 'MeasureConditionCode' do
    let(:xml_node) do
      {
        'conditionCode' => 'A',
        'measureConditionCodeDescription' => {
          'description' => 'Presentation of an anti-dumping/countervailing document',
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
        condition_code: 'A',
        language_id: 'EN',
        description: 'Presentation of an anti-dumping/countervailing document',
      }
    end
  end
end
