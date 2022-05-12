RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '21811',
        'quotaOrderNumberId' => '090718',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: nil,
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        quota_order_number_sid: 21_811,
        quota_order_number_id: '090718',
      }
    end

    let(:expected_entity_class) { 'QuotaOrderNumber' }
    let(:expected_mapping_root) { 'QuotaOrderNumber' }
  end
end
