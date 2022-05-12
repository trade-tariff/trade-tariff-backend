RSpec.describe CdsImporter::EntityMapper::MonetaryExchangePeriodMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '2927',
        'validityStartDate' => '2015-03-01T00:00:00',
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
        validity_start_date: Time.parse('2015-03-01T00:00:00.000Z'),
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        monetary_exchange_period_sid: 2927,
        parent_monetary_unit_code: 'EUR',
      }
    end

    let(:expected_entity_class) { 'MonetaryExchangePeriod' }
    let(:expected_mapping_root) { 'MonetaryExchangePeriod' }
  end
end
