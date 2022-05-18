RSpec.describe CdsImporter::EntityMapper::MeursingAdditionalCodeMapper do
  it_behaves_like 'an entity mapper', 'MeursingAdditionalCode', 'MeursingAdditionalCode' do
    let(:xml_node) do
      {
        'sid' => '3084',
        'additionalCodeCode' => '169',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1996-06-14T23:59:59.000Z'),
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        meursing_additional_code_sid: 3084,
        additional_code: '169',
      }
    end
  end
end
