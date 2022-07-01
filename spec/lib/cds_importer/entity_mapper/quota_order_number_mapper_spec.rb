RSpec.describe CdsImporter::EntityMapper::QuotaOrderNumberMapper do
  let(:xml_node) do
    {
      'sid' => '12348',
      'quotaOrderNumberId' => '090718',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:17',
      },
    }
  end

  it_behaves_like 'an entity mapper', 'QuotaOrderNumber', 'QuotaOrderNumber' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00.000Z'),
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        quota_order_number_sid: 12_348,
        quota_order_number_id: '090718',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaOrderNumber', xml_node) }

    context 'when there are missing secondary entities to be soft deleted' do
      before do
        # Creates entities that will be missing from the xml node
        create(:quota_order_number, :with_quota_order_number_origin, quota_order_number_sid: 12_348)
      end

      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper missing destroy operation', QuotaOrderNumberOrigin, quota_order_number_sid: '12348'
    end
  end
end
