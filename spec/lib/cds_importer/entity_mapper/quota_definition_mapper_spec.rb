RSpec.describe CdsImporter::EntityMapper::QuotaDefinitionMapper do
  it_behaves_like 'an entity mapper', 'QuotaDefinition', 'QuotaDefinition' do
    let(:xml_node) do
      {
        'sid' => '12113',
        'volume' => '30.000',
        'initialVolume' => '30.000',
        'maximumPrecision' => '3',
        'criticalThreshold' => '75',
        'criticalState' => 'N',
        'description' => 'some description',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'quotaOrderNumber' => {
          'sid' => '1485',
          'quotaOrderNumberId' => '092607',
        },
        'measurementUnit' => {
          'measurementUnitCode' => 'KGM',
        },
        'measurementUnitQualifier' => {
          'measurementUnitQualifierCode' => 'X',
        },
        'monetaryUnit' => {
          'monetaryUnitCode' => 'EUR',
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00.000Z'),
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        quota_definition_sid: 12_113,
        quota_order_number_sid: 1485,
        quota_order_number_id: '092607',
        volume: 30,
        initial_volume: 30,
        maximum_precision: 3,
        critical_state: 'N',
        critical_threshold: 75,
        monetary_unit_code: 'EUR',
        measurement_unit_code: 'KGM',
        measurement_unit_qualifier_code: 'X',
        description: 'some description',
      }
    end
  end
end
