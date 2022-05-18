RSpec.describe CdsImporter::EntityMapper::QuotaAssociationMapper do
  it_behaves_like 'an entity mapper', 'QuotaAssociation', 'QuotaDefinition' do
    let(:xml_node) do
      {
        'sid' => '12112',
        'volume' => '30.000',
        'initialVolume' => '30.000',
        'maximumPrecision' => '3',
        'criticalThreshold' => '75',
        'criticalState' => 'N',
        'quotaAssociation' => {
          'subQuotaDefinition' => {
            'sid' => '12341',
          },
          'relationType' => 'EQ',
          'coefficient' => '1.42',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-06-29T20:04:37',
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
        operation_date: Date.parse('2017-06-29'),
        main_quota_definition_sid: 12_112,
        sub_quota_definition_sid: 12_341,
        relation_type: 'EQ',
        coefficient: 1.42,
      }
    end
  end
end
