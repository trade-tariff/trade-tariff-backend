RSpec.describe CdsImporter::EntityMapper::AdditionalCodeDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '3084',
        'additionalCodeCode' => '169',
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'additionalCodeDescriptionPeriod' => {
          'sid' => '536',
          'additionalCodeDescription' => {
            'description' => 'Other.',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'origin' => 'T',
              'opType' => 'C',
              'transactionDate' => '2016-07-27T09:20:14',
            },
          },
        },
      }
    end

    let(:expected_values) do
      {
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        additional_code_description_period_sid: 536,
        language_id: 'EN',
        additional_code_sid: 3084,
        additional_code_type_id: '8',
        additional_code: '169',
        description: 'Other.',
      }
    end

    let(:expected_entity_class) { 'AdditionalCodeDescription' }
    let(:expected_mapping_root) { 'AdditionalCode' }
  end
end
