RSpec.describe CdsImporter::EntityMapper::RegulationGroupMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'hjid' => '440103',
        'regulationGroupId' => '123',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'T',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.parse('1972-01-01T00:00:00.000Z'),
        national: false,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        regulation_group_id: '123',
      }
    end

    let(:expected_entity_class) { 'RegulationGroup' }
    let(:expected_mapping_root) { 'RegulationGroup' }
  end
end
