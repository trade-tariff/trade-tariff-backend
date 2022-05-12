RSpec.describe CdsImporter::EntityMapper::MeursingTablePlanMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'meursingTablePlanId' => '01',
        'validityStartDate' => '1988-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:17',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('1988-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        meursing_table_plan_id: '01',
      }
    end

    let(:expected_entity_class) { 'MeursingTablePlan' }
    let(:expected_mapping_root) { 'MeursingTablePlan' }
  end
end
