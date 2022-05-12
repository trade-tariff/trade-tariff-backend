RSpec.describe CdsImporter::EntityMapper::QuotaBlockingPeriodMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '13321',
        'quotaBlockingPeriod' => {
          'quotaBlockingPeriodSid' => '16811',
          'blockingStartDate' => '2004-01-09T00:00:00',
          'blockingEndDate' => '2004-01-30T00:00:00',
          'blockingPeriodType' => 1,
          'description' => 'Council adoption anticipated 10.2.2004',
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
        quota_definition_sid: 13_321,
        blocking_start_date: Date.parse('2004-01-09'),
        blocking_end_date: Date.parse('2004-01-30'),
        blocking_period_type: 1,
        description: 'Council adoption anticipated 10.2.2004',
        quota_blocking_period_sid: 16_811,
      }
    end

    let(:expected_entity_class) { 'QuotaBlockingPeriod' }
    let(:expected_mapping_root) { 'QuotaDefinition' }
  end
end
