RSpec.describe CdsImporter::EntityMapper::MonetaryUnitDescriptionMapper do
  it_behaves_like 'an entity mapper', 'MonetaryUnitDescription', 'MonetaryUnit' do
    let(:xml_node) do
      {
        'monetaryUnitCode' => 'IEP',
        'monetaryUnitDescription' => {
          'description' => 'Irish pound',
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
        monetary_unit_code: 'IEP',
        language_id: 'EN',
        description: 'Irish pound',
      }
    end
  end
end
