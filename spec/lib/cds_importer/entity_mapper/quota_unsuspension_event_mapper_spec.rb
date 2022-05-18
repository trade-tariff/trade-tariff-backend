RSpec.describe CdsImporter::EntityMapper::QuotaUnsuspensionEventMapper do
  it_behaves_like 'an entity mapper', 'QuotaUnsuspensionEvent', 'QuotaDefinition' do
    let(:xml_node) do
      {
        'sid' => '12113',
        'quotaUnsuspensionEvent' => {
          'hjid' => '1485',
          'occurrenceTimestamp' => '2005-12-15T16:37:59',
          'unsuspensionDate' => '2004-02-16T00:00:00',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-04-11T10:05:31',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-04-11'),
        quota_definition_sid: 12_113,
        occurrence_timestamp: '2005-12-15T16:37:59.000Z',
        unsuspension_date: Date.parse('2004-02-16'),
      }
    end
  end
end
