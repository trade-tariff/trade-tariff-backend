RSpec.describe CdsImporter::EntityMapper::QuotaUnblockingEventMapper do
  it_behaves_like 'an entity mapper', 'QuotaUnblockingEvent', 'QuotaDefinition' do
    let(:xml_node) do
      {
        'sid' => '13412',
        'quotaUnblockingEvent' => {
          'occurrenceTimestamp' => '2004-02-16T14:10:40+0000',
          'unblockingDate' => '2004-02-16T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2016-07-27T09:20:17',
          },
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        quota_definition_sid: 13_412,
        occurrence_timestamp: Time.zone.parse('2004-02-16T14:10:40.000Z'),
        unblocking_date: Date.parse('2004-02-16'),
      }
    end
  end
end
