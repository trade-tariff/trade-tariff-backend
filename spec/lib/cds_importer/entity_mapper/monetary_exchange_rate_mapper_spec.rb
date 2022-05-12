RSpec.describe CdsImporter::EntityMapper::MonetaryExchangeRateMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => 2927,
        'validityStartDate' => '2015-03-01T00:00:00',
        'monetaryExchangeRate' => {
          'childMonetaryUnitCode' => 'SEK',
          'exchangeRate' => '0.9123',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2017-07-29T21:14:33',
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
        operation_date: Date.parse('2017-07-29'),
        monetary_exchange_period_sid: 2927,
        child_monetary_unit_code: 'SEK',
        exchange_rate: 0.9123,
      }
    end

    let(:expected_entity_class) { 'MonetaryExchangeRate' }
    let(:expected_mapping_root) { 'MonetaryExchangePeriod' }
  end
end
