RSpec.describe CdsImporter::EntityMapper::QuotaBalanceEventMapper do
  it_behaves_like 'an entity mapper', 'QuotaBalanceEvent', 'QuotaDefinition' do
    let(:xml_node) do
      {
        'sid' => '12113',
        'quotaBalanceEvent' => {
          'hjid' => '1485',
          'occurrenceTimestamp' => '2005-12-15T16:37:59',
          'lastImportDateInAllocation' => '2021-12-31T23:59:59',
          'oldBalance' => '12.2',
          'newBalance' => '13.4',
          'importedAmount' => '57173433.0',
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
        occurrence_timestamp: Time.zone.parse('2005-12-15T16:37:59.000Z'),
        last_import_date_in_allocation: Date.parse('2021-12-31'),
        old_balance: 12.2,
        new_balance: 13.4,
        imported_amount: 57_173_433.0,
      }
    end
  end
end
