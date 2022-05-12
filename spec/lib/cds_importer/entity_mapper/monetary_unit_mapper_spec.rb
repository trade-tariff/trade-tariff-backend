RSpec.describe CdsImporter::EntityMapper::MonetaryUnitMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'monetaryUnitCode' => 'IEP',
        'validityStartDate' => '1970-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1970-01-01T00:00:00.000Z',
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        monetary_unit_code: 'IEP',
      }
    end

    let(:expected_entity_class) { 'MonetaryUnit' }
    let(:expected_mapping_root) { 'MonetaryUnit' }
  end
end
