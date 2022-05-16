RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberMapper do
  it_behaves_like 'an entity mapper', 'QuotaOrderNumber', 'QuotaOrderNumber' do
    let(:xml_node) do
      {
        'sid' => '21811',
        'quotaOrderNumberId' => '090718',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00.000Z'),
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        quota_order_number_sid: 21_811,
        quota_order_number_id: '090718',
      }
    end
  end
end
