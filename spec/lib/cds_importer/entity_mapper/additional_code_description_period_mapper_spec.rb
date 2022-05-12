RSpec.describe CdsImporter::EntityMapper::AdditionalCodeDescriptionPeriodMapper do
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
          'validityStartDate' => '1991-06-01T00:00:00',
          'validityEndDate' => '1992-06-01T00:00:00',
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
        validity_start_date: Time.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.parse('1992-06-01T00:00:00.000Z'),
        operation: nil,
        operation_date: nil,
        additional_code_description_period_sid: 536,
        additional_code_sid: 3084,
        additional_code_type_id: '8',
        additional_code: '169',
      }
    end

    let(:expected_entity_class) { 'AdditionalCodeDescriptionPeriod' }
    let(:expected_mapping_root) { 'AdditionalCode' }
  end
end
