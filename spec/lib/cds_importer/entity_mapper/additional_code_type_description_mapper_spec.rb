RSpec.describe CdsImporter::EntityMapper::AdditionalCodeTypeDescriptionMapper do
  it_behaves_like 'an entity mapper', 'AdditionalCodeTypeDescription', 'AdditionalCodeType' do
    let(:xml_node) do
      {
        'additionalCodeTypeId' => '3',
        'additionalCodeTypeDescription' => {
          'description' => 'Prohibition/Restriction/Surveillance',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => 'C',
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
        additional_code_type_id: '3',
        language_id: 'EN',
        description: 'Prohibition/Restriction/Surveillance',
      }
    end
  end
end
