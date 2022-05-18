RSpec.describe CdsImporter::EntityMapper::QuotaSuspensionPeriodMapper do
  it_behaves_like 'an entity mapper', 'QuotaSuspensionPeriod', 'QuotaDefinition' do
    let(:xml_node) do
      {
        'sid' => '12113',
        'quotaSuspensionPeriod' => {
          'sid' => '1485',
          'suspensionStartDate' => '2005-12-15T16:37:59',
          'suspensionEndDate' => '2004-02-16T00:00:00',
          'description' => 'Description',
          'metainfo' => {
            'opType' => 'C',
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
        operation: 'C',
        operation_date: Date.parse('2017-04-11'),
        quota_suspension_period_sid: 1485,
        quota_definition_sid: 12_113,
        suspension_start_date: Date.parse('2005-12-15'),
        suspension_end_date: Date.parse('2004-02-16'),
        description: 'Description',
      }
    end
  end
end
