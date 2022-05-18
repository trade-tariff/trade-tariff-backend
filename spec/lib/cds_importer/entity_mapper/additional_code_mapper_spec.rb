RSpec.describe CdsImporter::EntityMapper::AdditionalCodeMapper do
  it_behaves_like 'an entity mapper', 'AdditionalCode', 'AdditionalCode' do
    let(:xml_node) do
      {
        'sid' => '3084',
        'additionalCodeCode' => '169',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'additionalCodeType' => {
          'additionalCodeTypeId' => '8',
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1996-06-14T23:59:59.000Z'),
        national: false,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        additional_code_sid: 3084,
        additional_code_type_id: '8',
        additional_code: '169',
      }
    end
  end
end
